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
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information',

        [Parameter(Mandatory = $true)]
        [string]$logFile = "$env:Temp\LogFile.csv"
    )

    [pscustomobject]@{
        Time     = (Get-Date -f g)
        Severity = $Severity
        Message  = $Message
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
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI xml object")]
        [System.Xml.XmlDocument]$xml,

        [Parameter(Mandatory = $true, HelpMessage = "Enter Gross price")]
        [string]$grossprice,

        [Parameter(Mandatory = $true, HelpMessage = "Enter Net price")]
        [string]$netprice        
    )
    PROCESS {
        $gp = $xml.SelectNodes("//App_Data") | where-object { $_.Name -match "Gross_price" }

        if (($gp.count -eq 0)) {
            [xml]$childnode = "<App_Data App='MOD' Name='Gross_price' Value=''/>"
            $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true)) 
            $gp = $xml.SelectNodes("//App_Data") | where-object { $_.Name -match "Gross_price" }
            $gp.value = $grossprice
        }
        else {
            Write-Host "Gross_price already exists, skipping"
        }
        
        $np = $xml.SelectNodes("//App_Data") | where-object { $_.Name -match "Net_price" }
                
        if (($np.count -eq 0)) {
            [xml]$childnode = "<App_Data App='MOD' Name='Net_price' Value=''/>"
            $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true)) 
            $np = $xml.SelectNodes("//App_Data") | where-object { $_.Name -match "Net_price" }
            $np.value = $netprice
        }
        else {
            Write-Host "Net_price already exists, skipping"
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
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI xml object")]
        [System.Xml.XmlDocument]$xml,

        [Parameter(Mandatory = $true, HelpMessage = "Enter packages xml object")]
        [System.Xml.XmlDocument]$packages,     
           
        [Parameter(Mandatory = $true)]
        [string]$grossprice
    )
    PROCESS {
        if ($grossprice -lt 0.001) {
            # only assets with price of 0 can be SVOD
            # get existing tier information
            $pctier = $xml.SelectNodes("//App_Data") | where-object { $_.Name -match "Provider_Content_Tier" }
            if ($pctier.count -gt 1) {
                Write-Log -Message "Multiple Provider_Content_Tier nodes detected - "  -logFile $logFile
                foreach ($tier in $pctier) { $tierlist += $tier.value + "`r`n" } 
                Write-Log -Message $tierlist  -logFile $logFile
                $pctierval = $pctier[0].value  # if ADI has more than one Content tiers, pick first one until we figure out better logic
                Write-Log -Message "Provider_Content_Tier chosen for matching - $pctierval" -logFile $logFile
            }
            else {
                $pctierval = $pctier.value
                Write-Log -Message "Provider_Content_Tier=$pctierval" -logFile $logFile
            }
            $packagetier = $packages.SelectNodes("//Package[text()='$pctierval']").ParentNode.ParentNode.Name
            # we didn't find a match for the SVOD offer, add a default value
            if ($null -eq $packagetier) {$packagetier = "NOTFOUND"}
            # check for existing Package_offder_ID node
            $pkg = $xml.SelectNodes("//App_Data") | where-object { $_.Name -match "Package_offer_ID" }
            
            if (($pkg.count -eq 0 -and $null -ne $pctier)) { # add a new offer element
                Write-Log -Message "adding new node Package_offer_ID=$packagetier" -logFile $logFile
                [xml]$childnode = "<App_Data App='MOD' Name='Package_offer_ID' Value='" + $packagetier + "'/>"
                $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true)) 
            }
            elseif ($pkg.count -eq 1 -And $null -ne $packagetier) { # update existing offer element from package lookup
                $oldpackagetier = $pkg.value
                Write-Log -Message "old Package_offer_ID=$oldpackagetier" -logFile $logFile
                $pkg.value = $packagetier
                Write-Log -Message "new Package_offer_ID=$packagetier" -logFile $logFile
            }
            elseif ($pkg.count -eq 1 -And $null -eq $packagetier) { # update existing offer element from package lookup
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
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI xml object")]
        [System.Xml.XmlDocument]$xml,
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI file object")]
        [System.IO.FileInfo]$adifile
    )
    PROCESS {
        $assetid = $xml.SelectNodes("//AMS[@Asset_Class='title']").Asset_ID
        $timestamp = (get-date -Format yyyyMMdd) + "T" + (get-date -Format hhmmss) + "Z"
        $newFolderName = $assetid + "_" + $timestamp 
        $newFileName = $newFolderName + ".XML"
        $xml.Save($adifile)
        Rename-Item -Path $adifile.FullName -NewName $newFileName
        Rename-Item -Path $adifile.DirectoryName -NewName $newFolderName
        Write-Log -Message "New ADI filename is $newFileName" -logFile $logFile
        $newfolder = (get-childitem ((Split-path -parent $adifile.directoryname)) -Directory -Filter $newFolderName)
        Write-Log -Message "New ADI folder is $newfolder" -logFile $logFile
        return $newfolder 
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
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Enter folder to mark with .wfmready file")]
        [System.IO.DirectoryInfo]$folder
    )
    PROCESS {
        $files = Get-ChildItem $folder
        $adifile = Get-ChildItem $folder -Filter *.xml
        $recentFileWrite = $false
        foreach ($file in $files) {
                Write-host $File.name $file.LastWriteTime  
                Write-Host File is -($file.LastWriteTime - (Get-Date)) minutes old
                if ($file.LastWriteTime -ge (Get-Date).AddMinutes(-15)) {
                    if ($file.Name -ne $adifile.Name) {
                        #flag that file timestamps are too new to mark folder with .wfmready 
                        $recentFileWrite = $true
                        $timediff = ((Get-Date) - $file.LastWriteTime).TotalMinutes
                        Write-Log -Message "$file last write minutes ago: $timediff " -logFile $logFile
                        Write-host ""
                    }
            }
        }

        if ($recentFileWrite -eq $false) {
            Write-Log -Message "no new files, tagging folder with .wfmready file" -logFile $logFile
            new-item ($adifile.DirectoryName.tostring() + "/" + $adifile.BaseName + ".wfmready") -type file
        }
    }
} #End function


function Skip-CurrentlyCopyingAssets {
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
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Enter folder to check for recently modified files")]
        [System.IO.DirectoryInfo]$folder
    )
    PROCESS {
        $files = Get-ChildItem $folder
        [bool]$recentFileWrite = $false
        $delay = -1
        foreach ($file in $files) {
                if ($file.LastWriteTime -ge (Get-Date).AddMinutes($delay)) {
                    if ($file.Name -ne $adifile.Name) {
                        #flag that file timestamps are too new to mark folder with .wfmready 
                        $recentFileWrite = $true
                        Write-Log -Message "$file.name last write minutes ago: (Get-Time - $file.LastWriteTime).TotalMinutes - minimum delay is $delay" -logFile $logFile
                    }
                }
            }

        if ($recentFileWrite -eq $false) {
            Write-Log -Message "Folder doesn't appear to be currently copying files" -logFile $logFile
        }
        return $recentFileWrite
    }
} #End function