function Write-Log {
<#
    .Synopsis
    The short function description.
    .Description
        The long function description
    .Example
        C:\PS>Function-Name -param "Param Value"
        
        This example does something
    .Example
        C:\PS>
        
        You can have multiple examples
    .Notes
        Name: Function-Name
        Author: Author Name
        Last Edit: Date
        Keywords: Any keywords
    .Inputs
        None
    .Outputs
        None
    #Requires -Version 2.0
    #>
  [CmdletBinding()]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Message,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Information','Warning','Error')]
    [string]$Severity = 'Information',

    [Parameter(Mandatory = $true)]
    [string]$logFile = "$env:Temp\LogFile.csv"
  )

  [pscustomobject]@{
    Time = (Get-Date -f g)
    Severity = $Severity
    Message = $Message
  } | Export-Csv -Path $logFile -Append -NoTypeInformation
}

function Add-GrossNetPrice {
<#
    .Synopsis
    The short function description.
    .Description
        The long function description
    .Example
        C:\PS>Function-Name -param "Param Value"
        
        This example does something
    .Example
        C:\PS>
        
        You can have multiple examples
    .Notes
        Name: Function-Name
        Author: Author Name
        Last Edit: Date
        Keywords: Any keywords
    .Inputs
        None
    .Outputs
        None
    #Requires -Version 2.0
    #>
  [CmdletBinding(SupportsShouldProcess = $False)]
  param
  (
    [Parameter(Mandatory = $true,HelpMessage = "Enter ADI xml object")]
    [System.Xml.XmlDocument]$xml,

    [Parameter(Mandatory = $true,HelpMessage = "Enter Gross price")]
    [string]$grossprice,

    [Parameter(Mandatory = $true,HelpMessage = "Enter Net price")]
    [string]$netprice
  )
  process {
    try {
      $gp = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Gross_price" }

      if (($gp.count -eq 0)) {
        [xml]$childnode = "<App_Data App='MOD' Name='Gross_price' Value=''/>"
        $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data,$true))
        $gp = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Gross_price" }
        $gp.value = $grossprice
      }
      else {
        Write-Host "Gross_price already exists, skipping"
      }

      $np = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Net_price" }

      if (($np.count -eq 0)) {
        [xml]$childnode = "<App_Data App='MOD' Name='Net_price' Value=''/>"
        $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data,$true))
        $np = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Net_price" }
        $np.value = $netprice
      }
      else {
        Write-Host "Net_price already exists, skipping"
      }
    }
    catch
    {
      Write-Host $_.Exception.Message -ForegroundColor Yellow
      Write-Log -Message $_.Exception.Message -Severity "Error"
    }
  }
} #End function

function Add-SvodPackage {
<#
.Synopsis
  The short function description.
.Description
	The long function description
.Example
	C:\PS>Function-Name -param "Param Value"
	
	This example does something
.Example
	C:\PS>
    
	You can have multiple examples
.Notes
	Name: Function-Name
	Author: Author Name
	Last Edit: Date
	Keywords: Any keywords
.Inputs
	None
.Outputs
	None
#Requires -Version 2.0
#>
  [CmdletBinding(SupportsShouldProcess = $False)]
  param
  (
    [Parameter(Mandatory = $true,HelpMessage = "Enter ADI xml object")]
    [System.Xml.XmlDocument]$xml,

    [Parameter(Mandatory = $true,HelpMessage = "Enter packages xml object")]
    [System.Xml.XmlDocument]$packages,

    [Parameter(Mandatory = $true,HelpMessage = "Enter package XML node to use for lookup")]
    [string]$packagenode,

    [Parameter(Mandatory = $true)]
    [string]$grossprice
  )
  process {
    try {
      if ($grossprice -lt 0.001) {
        # only assets with price of 0 can be SVOD
        # get existing tier information
        if ($packagenode -eq "Provider_Content_Tier")
        {
        $pctier = ($xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match $packagenode }).Value
        } elseif ($packagenode -eq "Provider") {
          $pctier = $xml.SelectNodes("//AMS[@Asset_Class='package']").Provider  
        } else {
          ThrowError -ExceptionName "InvalidPackageNode" -ExceptionMessage "packagenode $packagenode was not found in packages.xml"
        }
        
        Write-Log -Message "Using $packagenode as package.xml lookup node" -logFile $logFile
        if ($pctier.count -gt 1) {
          Write-Log -Message "Multiple $packagenode nodes detected - " -logFile $logFile
          foreach ($tier in $pctier) { $tierlist += $tier + "`r`n" }
          Write-Log -Message $tierlist -logFile $logFile
          $pctierval = $pctier[0] # if ADI has more than one Content tiers, pick first one until we figure out better logic
          Write-Log -Message "$packagenode chosen for matching - $pctierval" -logFile $logFile
        }
        else {
          $pctierval = $pctier
          Write-Log -Message "$packagenode=$pctierval" -logFile $logFile
        }
        $packagetier = $packages.SelectNodes("//$packagenode[text()='$pctierval']").ParentNode.ParentNode.Name
        # we didn't find a match for the SVOD offer, add a default value
        if ($null -eq $packagetier) {
          $packagetier = "NOTFOUND"
          Write-Log -Message "Did not find a match for $pctierval - update Packages.xml with tier information" -logFile $logFile -Severity Warning
        }
        # check for existing Package_offder_ID node
        $pkg = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Package_offer_ID" }

        if (($pkg.count -eq 0 -and $null -ne $pctier)) { # add a new offer element
          Write-Log -Message "adding new node Package_offer_ID=$packagetier" -logFile $logFile
          [xml]$childnode = "<App_Data App='MOD' Name='Package_offer_ID' Value='" + $packagetier + "'/>"
          $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data,$true))
        }
        elseif ($pkg.count -eq 1 -and $null -ne $packagetier) { # update existing offer element from package lookup
          $oldpackagetier = $pkg.value
          Write-Log -Message "old Package_offer_ID=$oldpackagetier" -logFile $logFile
          $pkg.value = $packagetier
          Write-Log -Message "new Package_offer_ID=$packagetier" -logFile $logFile
        }
        elseif ($pkg.count -eq 1 -and $null -eq $packagetier) { # update existing offer element from package lookup
          $oldpackagetier = $pkg.value
          Write-Log -Message "old package tier was null" -logFile $logFile
          Write-Log -Message "old Package_offer_ID=$oldpackagetier" -logFile $logFile
          $pkg.value = $packagetier
          Write-Log -Message "new Package_offer_ID=$packagetier" -logFile $logFile
        }
        else {
          $msg = "Add-SvodPackage - skipping"
          $msg += "`r`nProvider_Content_Tier=$pctierval"
          $msg += "`r`npackagetier=$packagetier"
          $msg += "`r`grossprice=$grossprice"
          $msg += "`r`Package_offer_ID=" + $pkg.value
          Write-Host $msg
          Write-Log -Message $msg -logFile $logFile
        }
      }
    }
    catch
    {
      Write-Host $_.Exception.Message -ForegroundColor Yellow
      Write-Log -Message $_.Exception.Message -Severity "Error"
    }
  }
} #End function

function Rename-AssetAndFolder {
<#
    .Synopsis
      The short function description.
    .Description
        The long function description
    .Example
        C:\PS>Function-Name -param "Param Value"
        
        This example does something
    .Example
        C:\PS>
        
        You can have multiple examples
    .Notes
        Name: Function-Name
        Author: Author Name
        Last Edit: Date
        Keywords: Any keywords
    .Inputs
        None
    .Outputs
        None
    #Requires -Version 2.0
    #>
  [CmdletBinding(SupportsShouldProcess = $False)]
  param
  (
    [Parameter(Mandatory = $true,HelpMessage = "Enter ADI xml object")]
    [System.Xml.XmlDocument]$xml,
    [Parameter(Mandatory = $true,HelpMessage = "Enter ADI file object")]
    [System.IO.FileInfo]$adifile
  )
  process {
    try {
      $assetid = $xml.SelectNodes("//AMS[@Asset_Class='title']").Asset_ID
      $timestamp = (Get-Date -Format yyyyMMdd) + "T" + (Get-Date -Format hhmmss) + "Z"
      $newFolderName = $assetid + "_" + $timestamp
      $newFileName = $newFolderName + ".XML"
      $xml.Save($adifile)
      Rename-Item -Path $adifile.FullName -NewName $newFileName
      Rename-Item -Path $adifile.DirectoryName -NewName $newFolderName
      Write-Log -Message "New ADI filename is $newFileName" -logFile $logFile
      $newfolder = (Get-ChildItem ((Split-Path -Parent $adifile.DirectoryName)) -Directory -Filter $newFolderName)
      Write-Log -Message "New ADI folder is $newfolder" -logFile $logFile
      return $newfolder
    }
    catch
    {
      Write-Host $_.Exception.Message -ForegroundColor Yellow
      Write-Log -Message $_.Exception.Message -Severity "Error"
    }
  }
} #End function

function Add-WfmReadyFile {
<#
        .Synopsis
          The short function description.
        .Description
            The long function description
        .Example
            C:\PS>Function-Name -param "Param Value"
            
            This example does something
        .Example
            C:\PS>
            
            You can have multiple examples
        .Notes
            Name: Function-Name
            Author: Author Name
            Last Edit: Date
            Keywords: Any keywords
        .Inputs
            None
        .Outputs
            None
        #Requires -Version 2.0
        #>
  [CmdletBinding(SupportsShouldProcess = $False)]
  param
  (
    [Parameter(Mandatory = $true,HelpMessage = "Enter folder to mark with .wfmready file")]
    [System.IO.DirectoryInfo]$folder
  )
  process {
    try {
      $files = Get-ChildItem $folder
      $adifile = Get-ChildItem $folder -Filter *.xml
      $delay = -5
      $recentFileWrite = $false
      foreach ($file in $files) {
        Write-Host $File.Name $file.LastWriteTime
        Write-Host File is - ($file.LastWriteTime - (Get-Date)) minutes old
        if ($file.LastWriteTime -ge (Get-Date).AddMinutes($delay)) {
          if ($file.Name -ne $adifile.Name) {
            #flag that file timestamps are too new to mark folder with .wfmready 
            $recentFileWrite = $true
            $timediff = ((Get-Date) - $file.LastWriteTime).TotalMinutes | ForEach-Object { $_.ToString("#.#") }
            Write-Log -Message "$file last write minutes ago: $timediff " -logFile $logFile
            Write-Host ""
          }
        }
      }

      if ($recentFileWrite -eq $false) {
        Write-Log -Message "no new files, tagging folder with .wfmready file" -logFile $logFile
        New-Item ($adifile.DirectoryName.ToString() + "/" + $adifile.BaseName + ".wfmready") -Type file
      }
    }
    catch
    {
      Write-Host $_.Exception.Message -ForegroundColor Yellow
      Write-Log -Message $_.Exception.Message -Severity "Error"
    }
  }
} #End function


function Skip-CurrentTransfers {
<#
        .Synopsis
          The short function description.
        .Description
            The long function description
        .Example
            C:\PS>Function-Name -param "Param Value"
            
            This example does something
        .Example
            C:\PS>
            
            You can have multiple examples
        .Notes
            Name: Function-Name
            Author: Author Name
            Last Edit: Date
            Keywords: Any keywords
        .Inputs
            $folder - folder to check for files with recent timestamps (currently copying files)
        .Outputs
            [bool]$recentFileWrite
        #Requires -Version 2.0
        #>
  [CmdletBinding(SupportsShouldProcess = $False)]
  param
  (
    [Parameter(Mandatory = $true,HelpMessage = "Enter folder to check for recently modified files")]
    [System.IO.DirectoryInfo]$folder
  )
  process {
    try {
      $files = Get-ChildItem $folder
      [bool]$recentFileWrite = $false
      $delay = -1
      foreach ($file in $files) {
        if ($file.LastWriteTime -ge (Get-Date).AddMinutes($delay)) {
          if ($file.Name -ne $adifile.Name) {
            #flag that file timestamps are too new to mark folder with .wfmready 
            $recentFileWrite = $true
            $timediff = ((Get-Date) - $file.LastWriteTime).TotalMinutes | ForEach-Object { $_.ToString("#.#") }
            Write-Log -Message "Skip-CurrentTransfer - $file last write minutes ago: $timediff " -logFile $logFile
            Write-Host ""
          }
        }
      }

      if ($recentFileWrite -eq $false) {
        Write-Log -Message "Folder doesn't appear to be currently copying files" -logFile $logFile
      }
      return $recentFileWrite
    }
    catch
    {
      Write-Host $_.Exception.Message -ForegroundColor Yellow
      Write-Log -Message $_.Exception.Message -Severity "Error"
    }
  }
} #End function


function Get-XMLFileCount {
  <#
          .Synopsis
            The short function description.
          .Description
              The long function description
          .Example
              C:\PS>Function-Name -param "Param Value"
              
              This example does something
          .Example
              C:\PS>
              
              You can have multiple examples
          .Notes
              Name: Function-Name
              Author: Author Name
              Last Edit: Date
              Keywords: Any keywords
          .Inputs
              $folder - folder to check for files with recent timestamps (currently copying files)
          .Outputs
              [bool]$recentFileWrite
          #Requires -Version 2.0
          #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    param
    (
      [Parameter(Mandatory = $true,HelpMessage = "Enter folder to check XML file count")]
      [System.IO.DirectoryInfo]$folder
    )
    process {
      try {
        $files = Get-ChildItem $folder -Filter *.xml
        if ($files.count -gt 1)
        {
           Write-Log -Message "$folder.FullName contains multiple XML files: $files" -logFile $logFile -Severity "Warning"}
      }
       catch
      {
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Log -Message $_.Exception.Message -Severity "Error"
      }
    }
  } #End function
  