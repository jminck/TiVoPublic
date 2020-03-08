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
            return $files.count
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function
 


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
            if (!(test-path ($adifile.directoryname + "/.deleteready")) -and (test-path ($adifile.DirectoryName + "/" + $adifile.BaseName + ".wfmready")) ) {
      
                #remove extra violence advisries
                $v_advisories = $xml.ADI.Asset.Metadata.App_Data | Where-Object { $_.Name -eq "Advisories" -and $_.value -like "*V*" }
                if ($v_advisories.count -gt 1) {
                    Write-Log -Message "Found multiple violence advisories" -logFile $logFilea
                    for ($i = 1; $i -lt $v_advisories.count; $i++) {
                        $v = $v_advisories[$i]
                        Write-Log -Message "removing advistory $v.value" -logFile $logFile
                        $v.ParentNode.RemoveChild($v)
                    }
                }
    
                #remove trailing spaces in category names
                $categories = $xml.ADI.Asset.Metadata.App_Data | Where-Object { $_.Name -eq "Category" }
                foreach ($c in $categories) {
                    Write-Log -Message "checking $c.value for trailing spaces" -logFile $logFile
                    $c_newvalue = $c.value.replace(" /", "/")
                    if ($c.value -ne $c_newvalue) {
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





function Sort-AssetsByRating {
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
            write-host "processing $adifile"
            $rating = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Rating']").value
            if ($adifile.DirectoryName -Match $rating) {
                Write-Log -Message "$adifile.DirectoryName already contains $rating"  -logFile $logFile
            }
            else {
                $outfolder = (get-item $adifile.DirectoryName).parent.fullname + "/" + $rating
                if (!(Test-Path $outfolder)) { New-Item -ItemType "directory" -Path $outfolder }
                move-item $adifile.Directory $outfolder
                Get-ChildItem $outfolder
            }
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function

function Sort-AssetsByType {
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
            write-host "processing $adifile"
            Write-Log -Message "processing $adifile"  -logFile $logFile
            $grossprice = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Gross_price']").value
            $packageofferid = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Package_offer_ID']").value

            if (($null -eq $grossprice) -and ($null -eq $packageofferid)) {
                $type = "NOTYPE"
            }  
            elseif (($grossprice -lt 0.001) -and ($null -eq $packageofferid)) {
                $type = "ZVOD"
            } 
            elseif (($null -eq $grossprice) -and ($null -ne $packageofferid)) {
                $type = "SVOD"
            }
            elseif (($null -ne $grossprice) -and ($null -ne $packageofferid)) {
                $type = "SVOD-ZVOD"
            }            
            else {
                $type = "TVOD"
            }

            if ($adifile.DirectoryName -Match $type) {
                Write-Log -Message "$adifile.DirectoryName already contains $type"  -logFile $logFile
            }
            else {
                $outfolder = (get-item $adifile.DirectoryName).parent.fullname + "/" + $type
                if (!(Test-Path $outfolder)) 
                { New-Item -ItemType "directory" -Path $outfolder }
                move-item $adifile.Directory $outfolder
                Get-ChildItem $outfolder
            }
                
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function


function Sort-AssetsBySeries {
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
            write-host "processing $adifile"
            Write-Log -Message "processing $adifile"  -logFile $logFile
                  
            $element = "Title_Brief"
            $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
            Write-Host $element - $v
            $s = $null
            if (($ep = [regex]::match($v, 'S\d:\d\d')).Length -gt 0) {
                $s = $v.Substring(0, $ep.index - 1)
                Write-Host Series is $s
            }
            elseif (($ep = [regex]::match($v, '.*:')).Length -gt 0) {
                $s = $v.Substring(0, $ep.length - 1)
                Write-Host Series is $s
            }            
            elseif (($ep = [regex]::match($v, '\d\d-\d\d')).Length -gt 0) {
                $s = $v.Substring(0, $ep.index - 1)
                Write-Host Series is $s
            }
            elseif (($ep = [regex]::match($v, 'S\d{1,3}_E\d{1,3}')).Length -gt 0) {
                $s = $v.Substring(0, $ep.index - 1)
                Write-Host Series is $s
            }
            elseif (($ep = [regex]::match($v, 'S\d{1,3} Ep\d\d')).Length -gt 0) {
                $s = $v.Substring(0, $ep.index - 1)
                Write-Host Series is $s
            }
            elseif (($ep = [regex]::match($v, 'S\d E\d')).Length -gt 0) {
                $s = $v.Substring(0, $ep.index - 1)
                Write-Host Series is $s
            }            
            elseif (($ep = [regex]::match($v, '\d\d\d [HS]D')).Length -gt 0) {
                $s = $v.Substring(0, $ep.index - 1)
                Write-Host Series is $s
            }
        
            
            #account for movies too                          
            $element = "Title_Sort_Name"
            $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
            Write-Host $element - $v
            if (($ep = [regex]::match($v, '\d\d\d$')).Length -gt 0) {
                $s = $v.Substring(0, $ep.index - 1)
                Write-Host Series is $s
            }

            
            #account for movies too                          
            $element = "Category"
            $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
            Write-Host $element - $v
            if (($ep = [regex]::match($v, 'Movies')).Length -gt 0) {
                $s = "Movies"
                Write-Host Series is $s
            }

            $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
            Write-Host $element - $v
            if (($ep = [regex]::match($v, 'Cartoon')).Length -gt 0) {
                $s = "Cartoons"
                Write-Host Series is $s
            }

            if ($s) {
                if ($adifile.DirectoryName -Match $s) {
                    Write-Log -Message "$adifile.DirectoryName already contains $s"  -logFile $logFile
                }
                else {
                    $outfolder = (get-item $adifile.DirectoryName).parent.fullname + "/" + $s
                    if (!(Test-Path $outfolder)) 
                    { New-Item -ItemType "directory" -Path $outfolder }
                    move-item $adifile.Directory $outfolder
                    Get-ChildItem $outfolder
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



function Sort-AssetsByCategory {
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
            write-host "processing $adifile"
            Write-Log -Message "processing $adifile"  -logFile $logFile
 
            $element = "Category"
            $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
            Write-Host $element - $v
            if (($ep = [regex]::match($v, 'TV Networks')).Length -gt 0) {
                $s = $v.Substring($ep.Length,$v.length-$ep.length)
                Write-Host Series is $s
            }
                       
            $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
            Write-Host $element - $v
            if (($ep = [regex]::match($v, 'Movies')).Length -gt 0) {
                $s = "Movies"
                Write-Host Series is $s
            }


            if ($s) {
                if ($adifile.DirectoryName -Match $s) {
                    Write-Log -Message "$adifile.DirectoryName already contains $s"  -logFile $logFile
                }
                else {
                    $outfolder = (get-item $adifile.DirectoryName).parent.fullname + "/" + $s
                    if (!(Test-Path $outfolder)) 
                    { New-Item -ItemType "directory" -Path $outfolder }
                    move-item $adifile.Directory $outfolder
                    Get-ChildItem $outfolder
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

        [Parameter(Mandatory = $true)]
        [string]$grossprice,

        [Parameter(Mandatory = $false)]
        [string]$packagename = "super-svod"

    )
    process {
        try {
            if ($grossprice -lt 0.001) {
                # only assets with price of 0 can be SVOD
                # get existing tier information

                # check for existing Package_offder_ID node
                $pkg = $xml.SelectNodes("//App_Data") | Where-Object { $_.Name -match "Package_offer_ID" }

                if ((($pkg.count -eq 0 -or $null -eq $pkg ) -and $null -ne $packagename)) {
                    # add a new offer element
                    Write-Log -Message "adding new node Package_offer_ID=$packagename" -logFile $logFile
                    [xml]$childnode = "<App_Data App='MOD' Name='Package_offer_ID' Value='" + $packagename + "'/>"
                    $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true))
                }
                elseif ($pkg.count -eq 1 -and $null -ne $packagename) {
                    # update existing offer element from package lookup
                    $oldpackagetier = $pkg.value
                    Write-Log -Message "old Package_offer_ID=$oldpackagetier" -logFile $logFile
                    $pkg.value = $packagename
                    Write-Log -Message "new Package_offer_ID=$packagename" -logFile $logFile
                }
                elseif ($pkg.count -eq 1 -and $null -eq $packagename) {
                    # update existing offer element from package lookup
                    $oldpackagetier = $pkg.value
                    Write-Log -Message "old package tier was null" -logFile $logFile
                    Write-Log -Message "old Package_offer_ID=$oldpackagetier" -logFile $logFile
                    $pkg.value = $packagename
                    Write-Log -Message "new Package_offer_ID=$packagename" -logFile $logFile
                }
                else {
                    $msg = "Add-SvodPackage - skipping"
                    $msg += "`r`nProvider_Content_Tier=$pctierval"
                    $msg += "`r`npackagetier=$packagename"
                    $msg += "`r`grossprice=$grossprice"
                    $msg += "`r`Package_offer_ID=" + $pkg.value
                    Write-Host $msg
                    Write-Log -Message $msg -logFile $logFile
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



function Set-FileAndFolderName {
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
        [System.IO.FileInfo]$adifile,
    
        [Parameter(Mandatory = $false, HelpMessage = "Set to true if only updating folder timestamp, not renaming ADI file")]
        [bool]$folderonly = $false

    )
    process {
        try {
            $assetid = $xml.SelectNodes("//AMS[@Asset_Class='title']").Asset_ID
            $newfilename = $assetid + ".XML"
            $timestamp = (get-date -Format yyyyMMdd) + "T" + (get-date -Format HHmmss) + "Z"
            $newfoldername = $assetid + "-" + $timestamp 
            $folder = $adifile.directoryname
            if ($folderonly -eq $false)
            {
                rename-item $adifile.FullName $newfilename  
                Write-Host new file name: $newfilename
            }
            rename-item $folder  $newfoldername
            Write-Host new folder name: $newfoldername
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function

function Update-LicenseWindow {
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

        [Parameter(Mandatory = $false)]
        [string]$licensestart = "2019-01-01T00:00:00",

        [Parameter(Mandatory = $false)]
        [string]$licenseend = "2037-01-01T00:00:00"

    )
    process {
        try {
            write-host "processing $adifile"
            $x = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Licensing_Window_Start']")
            $x.Item(0).Value = $licensestart
            $y = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Licensing_Window_End']")
            $y.Item(0).Value = $licenseend
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function
