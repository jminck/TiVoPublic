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
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI xml object")]
        [System.Xml.XmlDocument]$xml,

        [Parameter(Mandatory = $true, HelpMessage = "Enter Gross price")]
        [string]$grossprice,

        [Parameter(Mandatory = $true, HelpMessage = "Enter Net price")]
        [string]$netprice
    )
    process {
        try {
            $gp = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Gross_price" }

            if (($gp.count -eq 0) -or ($gp -eq $null)) {
                [xml]$childnode = "<App_Data App='MOD' Name='Gross_price' Value=''/>"
                $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true))
                $gp = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Gross_price" }
                $gp.value = $grossprice
            }
            else {
                Write-Host "Gross_price already exists, skipping"
            }

            $np = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Net_price" }

            if (($np.count -eq 0) -or ($np -eq $null)) {
                [xml]$childnode = "<App_Data App='MOD' Name='Net_price' Value=''/>"
                $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true))
                $np = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Net_price" }
                $np.value = $netprice
            }
            else {
                Write-Host "Net_price already exists, skipping"
            }
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function

function Compare-AdiToPackageXml {
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
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI xml object")]
        [System.Xml.XmlDocument]$xml,

        [Parameter(Mandatory = $true, HelpMessage = "Enter packages xml object")]
        [System.Xml.XmlDocument]$packages,

        [Parameter(Mandatory = $true, HelpMessage = "Enter package XML node to use for lookup")]
        [string]$packagenode,

        [Parameter(Mandatory = $true)]
        [string]$grossprice,

        [Parameter(Mandatory = $false)]
        [string]$tier
    )
    process {
        try {
            $exists = $false
            Write-Log -Message "Entering Compare-AdiToPackageXml" -logFile $logFile
            if ($grossprice -lt 0.001) {
                # only assets with price of 0 can be SVOD
                # get existing tier information
                if ($packagenode -eq "Provider_Content_Tier") {
                    $pctier = ($xml.SelectNodes("//App_Data") | Where-Object { $_.Value -match $tier }).Value
                }
                elseif ($packagenode -eq "Provider") {
                    $pctier = $xml.SelectNodes("//AMS[@Asset_Class='package']").Provider  
                }
                else {
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
                # we didn't find a match for the SVOD offer
                if ($null -eq $packagetier) {
                    $packagetier = "NOTFOUND"
                    Write-Log -Message "Did not find a match for $pctierval - update Packages.xml with tier information if this asset should be associated with an SVOD package" -logFile $logFile -Severity Warning
                }
                else {
                    # check for existing Package_offder_ID node
                    Write-Log -Message "Found a match for $pctierval" -logFile $logFile -Severity Information
                    $exists = $true
                }
            }
            return $exists
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
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
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI xml object")]
        [System.Xml.XmlDocument]$xml,

        [Parameter(Mandatory = $true, HelpMessage = "Enter packages xml object")]
        [System.Xml.XmlDocument]$packages,

        [Parameter(Mandatory = $true)]
        [string]$grossprice
    )
    process {
        try {
            if ($grossprice -lt 0.001) {
                # only assets with price of 0 can be SVOD
                # get existing tier information

                $provider = $xml.SelectNodes("//AMS[@Asset_Class='package']").Provider  
                $provider_id = $xml.SelectNodes("//AMS[@Asset_Class='package']").Provider_ID  

                Write-Log -Message "Provider chosen for matching - $provider" -logFile $logFile
                Write-Log -Message "Provider_ID chosen for matching - $provider" -logFile $logFile
                $packagetier = $packages.SelectNodes("//Provider[text()='$provider']").ParentNode.ParentNode.Name
                if ($null -eq $packagetier) { #didn't find a Provider package tier, check Provider_ID
                    $packagetier = $packages.SelectNodes("//Provider_ID[text()='$provider_id']").ParentNode.ParentNode.Name
                    if ($null -ne $packagetier) {
                        Write-Log -Message "Provider_ID was chosen for matching - $provider_id with packge ID $packagetier" -logFile $logFile
                    }
                }
                else {
                    Write-Log -Message "Provider was chosen for matching - $provider with packge ID $packagetier" -logFile $logFile
                }
                # we didn't find a match for the SVOD offer
                if ($null -eq $packagetier) {
                    $packagetier = "NOTFOUND"
                    Write-Log -Message "Did not find a match for $pctierval - update Packages.xml with tier information if this asset should be associated with an SVOD package" -logFile $logFile -Severity Warning
                }
                else {
                    # check for existing Package_offder_ID node
                    $pkg = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Package_offer_ID" }

                    if ((($pkg.count -eq 0 -or $null -eq $pkg ) -and $null -ne $packagetier)) {
                        # add a new offer element
                        Write-Log -Message "adding new node Package_offer_ID=$packagetier" -logFile $logFile
                        [xml]$childnode = "<App_Data App='MOD' Name='Package_offer_ID' Value='" + $packagetier + "'/>"
                        $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true))
                    }
                    elseif ($pkg.count -eq 1 -and $null -ne $packagetier) {
                        # update existing offer element from package lookup
                        $oldpackagetier = $pkg.value
                        Write-Log -Message "old Package_offer_ID=$oldpackagetier" -logFile $logFile
                        $pkg.value = $packagetier
                        Write-Log -Message "new Package_offer_ID=$packagetier" -logFile $logFile
                    }
                    elseif ($pkg.count -eq 1 -and $null -eq $packagetier) {
                        # update existing offer element from package lookup
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
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
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
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI xml object")]
        [System.Xml.XmlDocument]$xml,
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI file object")]
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
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
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
        [Parameter(Mandatory = $true, HelpMessage = "Enter folder to mark with .wfmready file")]
        [System.IO.DirectoryInfo]$folder
    )
    process {
        try {
            $files = Get-ChildItem $folder.FullName -exclude *.xml, *.bak, *.jpg
            $adifile = Get-ChildItem $folder.FullName -Filter *.xml
            $delay = -1
            $recentFileWrite = $false
            foreach ($file in $files) {
                Write-Host $File.Name $file.LastWriteTime
                #Write-Host File is   ((Get-Date)-($file.LastWriteTime)) minutes old
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
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
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
        [Parameter(Mandatory = $true, HelpMessage = "Enter folder to check for recently modified files")]
        [System.IO.DirectoryInfo]$folder
    )
    process {
        try {
            $files = Get-ChildItem $folder -Exclude *.xml, *.bak, *.jpg
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
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function

function Test-AssetFilePath {
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
        [Parameter(Mandatory = $true, HelpMessage = "Enter folder to check for missing asset files")]
        [System.IO.DirectoryInfo]$folder
    )
    process {
        try {
            $files = Get-ChildItem $folder -Exclude *.xml, *.bak
            [bool]$recentFileWrite = $false
            $delay = -1
            foreach ($file in $files) {
                if ($file.LastWriteTime -ge (Get-Date).AddMinutes($delay)) {
                    if ($file.Name -ne $adifile.Name) {
                        #flag that file timestamps are too new to mark folder with .wfmready 
                        $recentFileWrite = $true
                        $timediff = ((Get-Date) - $file.LastWriteTime).TotalMinutes | ForEach-Object { $_.ToString("#.#") }
                        Write-Log -Message "Test-AssetFilePath - $file last write minutes ago: $timediff " -logFile $logFile
                        Write-Host ""
                    }
                }
            }

            if ($recentFileWrite -eq $false) {
                Write-Log -Message "Test-AssetFilePath - Folder doesn't appear to be currently copying files" -logFile $logFile
            }
            return $recentFileWrite
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
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
        [Parameter(Mandatory = $true, HelpMessage = "Enter folder to check XML file count")]
        [System.IO.DirectoryInfo]$folder
    )
    process {
        try {
            $files = Get-ChildItem $folder -Filter *.xml
            if ($files.count -gt 1) {
                Write-Log -Message "$folder.FullName contains multiple XML files: $files" -logFile $logFile -Severity "Warning"
            }
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function
 

function Convert-PosterBmpToJpg {
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
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI file to process")]
        [System.IO.FileInfo]$adifile,
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI xml object")]
        [System.Xml.XmlDocument]$xml
    )
    process {
        try {
            #try to find the path to magick.exe
            if ($Env:OS) {
                $magic = "C:\Program Files\ImageMagick-7.0.8-Q16\magick.exe"
                if (!(Test-Path $magic)) {
                    Write-Log -Message  "did not find $magic" -logFile $logFile
                    Write-Log -Message "This script depends on ImageMagick to be installed https://imagemagick.org" -logFile $logFile
                    throw "did not find $magic"
                }
            }
            elseif ($null -ne (Get-Command "convert" -ErrorAction SilentlyContinue)) {
                $magic = $null
            }
            else {
                Write-Log -Message "This script depends on ImageMagick to be installed https://imagemagick.org" -logFile $logFile
                Throw "This script depends on ImageMagick to be installed https://imagemagick.org"
            }
            write-host "processing $adifile for conversion of BMP to JPG poster"
  
            if ($xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.ParentNode.Content.Value -like "*bmp") {
                $passetname = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.ParentNode.Content
                $bmppath = $adifile.DirectoryName + "\" + $passetname.value
                if ($IsLinux -or $IsMacOS) {
                    $bmppath = $bmppath.replace("\", "/")
                }
                if (Test-Path $bmppath) {
                    Write-log -Message "$bmppath was found, continuing" -logFile $logFile        
                
                    $jpgpath = $bmppath.Replace(".bmp", ".jpg")
                    Write-log -Message "processing $adifile.FullName" -logFile $logFile 
                    Write-log -Message "converting $bmppath" -logFile $logFile 
                    if ($null -eq $magic) {
                        #windows uses "magic.exe convert", linux and mac just use "convert"
                        $result = convert $bmppath $jpgpath #needs ImageMagick installed
                    }
                    else {
                        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
                        $pinfo.FileName = "$magic"
                        $pinfo.RedirectStandardError = $true
                        $pinfo.RedirectStandardOutput = $true
                        $pinfo.UseShellExecute = $false
                        $pinfo.Arguments = "convert -verbose $bmppath $jpgpath"
                        $p = New-Object System.Diagnostics.Process
                        $p.StartInfo = $pinfo
                        $p.Start() | Out-Null
                        $p.WaitForExit()
                        $stdout = $p.StandardOutput.ReadToEnd()
                        $stderr = $p.StandardError.ReadToEnd()
                        Write-Host "stdout: $stdout"
                        Write-Host "stderr: $stderr"
                        Write-Host "exit code: " + $p.ExitCode
                        Write-log -Message "magick convert output: $stdout $stderr" -logFile $logFile 
                    }


                    if (Test-Path $jpgpath) {
                        $jpg = get-item $jpgpath
                        $md5 = (Get-FileHash -Algorithm MD5 $jpg.FullName).hash
                        $filesize = $jpg.Length
                    }
                    $passetname.value = $jpg.name
                    $pchecksum = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.App_Data | Where { $_.Name -eq "Content_CheckSum" }
                    $pchecksum.Value = $md5
                    $pfilesize = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.App_Data | Where { $_.Name -eq "Content_FileSize" }    
                    $pfilesize.Value = $filesize.toString()
                    if ($null -eq $magic) {
                        $dimensions = identify -ping -format "%w x %h" $jpg.FullName
                    }
                    else {
                        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
                        $pinfo.FileName = "$magic"
                        $pinfo.RedirectStandardError = $true
                        $pinfo.RedirectStandardOutput = $true
                        $pinfo.UseShellExecute = $false
                        $pinfo.Arguments = "identify -verbose -ping -format `"%w x %h`" $jpg"
                        $p = New-Object System.Diagnostics.Process
                        $p.StartInfo = $pinfo
                        $p.Start() | Out-Null
                        $p.WaitForExit()
                        $dimensions = $p.StandardOutput.ReadToEnd()
                        $stderr = $p.StandardError.ReadToEnd()
                        Write-Host "stdout: $dimensions"
                        Write-Host "stderr: $stderr"
                        Write-Host "exit code: " + $p.ExitCode
                        Write-log -Message "magick identify output: $dimensions $stderr" -logFile $logFile 
                    }
                    $pdimensions = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.App_Data | Where { $_.Name -eq "Image_Aspect_Ratio" }    
                    if ($null -ne $pdimensions) {
                        $pdimensions.Value = $dimensions.Replace(" ", "")
                    }

                    $xml.Save($adifile.fullname)
                }
                else {
                    Write-Host Asset Poster image $bmppath was not found!
                    Write-log -Message "$adifile.fullname Asset Poster image $bmppath was not found!" -logFile $logFile 
                    $dt =  (Get-Date)
                    Set-Content -Path ($adifile.DirectoryName + "/wfm-preprocessor.failure") -Value  "$dt - ERROR poster file $bmppath was not found in asset folder"
                }
            }
            else {
                Write-Host Asset $adifile.fullname did not have a poster node with a .bmp
                Write-log -Message "$adifile.fullname did not have a poster node with a .bmp" -logFile $logFile 
            } 
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
           
        }
    
    } 
} # end function


function Repair-ADIErrors {
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
        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI xml object")]
        [System.Xml.XmlDocument]$xml,

        [Parameter(Mandatory = $true, HelpMessage = "Enter ADI file to process")]
        [System.IO.FileInfo]$adifile

    )
    process {
        try {
            if (!(test-path ($adifile.directoryname + "/.deleteready")) -and (test-path ($adifile.DirectoryName + "/" + $adifile.BaseName + ".wfmready")) )
            {
      
                    #remove extra violence advisries
                    $v_advisories = $xml.ADI.Asset.Metadata.App_Data | Where-Object {$_.Name -eq "Advisories" -and $_.value -like "*V*"}
                    if ($v_advisories.count -gt 1)
                    {
                        Write-Log -Message "Found multiple violence advisories" -logFile $logFilea
                        for ($i=1;$i -lt $v_advisories.count;$i++)
                        {
                            $v = $v_advisories[$i]
                            Write-Log -Message "removing advistory $v.value" -logFile $logFile
                            $v.ParentNode.RemoveChild($v)
                        }
                    }
    
                    #remove trailing spaces in category names
                    $categories = $xml.ADI.Asset.Metadata.App_Data | Where-Object {$_.Name -eq "Category" }
                    foreach ($c in $categories)
                    {
                        Write-Log -Message "checking $c.value for trailing spaces" -logFile $logFile
                        $c_newvalue = $c.value.replace(" /","/")
                        if ($c.value -ne $c_newvalue)
                        {
                             $c.value = $c_newvalue
                        }
                    }
                
            }
            else {
                Write-Log -Message ".deleteready found in folder, or missing .wfmready, skipping $adifile" -logFile $logFile
            }     
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function