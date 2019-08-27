
<#
    .SYNOPSIS
        This script updates asset version fore reimport
    .DESCRIPTION
        This script wil increment the Version_Major of all assets in the ADI file, and update the asset's folder name with a new timestamp
        to allow the asset to be re-ingest after a failed attempt to ingest, or other correction made to ADI data.
#>

# load helper functions
. ./PreprocessorFunctions.ps1

$logFile = "./fixadi-updateassetversion-" + (Get-Date -Format yyyy-MM-dd) + ".log"
$adifiles = Get-ChildItem -Recurse "\assets\Armstrong\SanityCheck\1" -Filter *.xml
Write-Log -Message "ADI files found: $adifiles.Count" -logFile $logFile

$confirmation = $null

foreach ($adifile in $adifiles)
    {
        $update = $false
        if (!(test-path ($adifile.directoryname + "/.deleteready")) -and (test-path ($adifile.DirectoryName + "/" + $adifile.BaseName + ".wfmready")) )
        {
            write-host "processing $adifile"
            Write-Log -Message "processing $adifile" -logFile $logFile
            if ($confirmation -ne "a")
            {
            $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
            }

            if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
                $xml = [xml](Get-Content $adifile)

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
                    $update = $true
                }

                #remove trailing spaces in category names
                $categories = $xml.ADI.Asset.Metadata.App_Data | Where-Object {$_.Name -eq "Category" }
                foreach ($c in $categories)
                {
                    Write-Log -Message "checking $c.value for trailing spaces" -logFile $logFile
                    $c_newvalue = $c.value.replace(" /","/")
                    if ($c.value -ne $c_newvalue)
                    {
                        $update = $true
                        $c.value = $c_newvalue
                    }
                }

                if ($true -eq $update)
                {
                    #rev version number
                    [int]$version = $xml.ADI.Metadata.AMS.Version_Minor
                    $version++
                    $props = $xml.SelectNodes("//AMS") 
                    foreach ($vmaj in $props) {$vmaj.SetAttribute("Version_Minor",$version)}
                    $xml.Save($adifile)
                    $assetid = $xml.SelectNodes("//AMS[@Asset_Class='title']").Asset_ID
                    $timestamp = (get-date -Format yyyyMMdd) + "T" + (get-date -Format hhmmss) + "Z"
                    $newfolder = $assetid + "_" + $timestamp 
                    $folder = $adifile.directoryname
                    rename-item $folder $newfolder  
                    start-sleep -Milliseconds 100     
                } 
            }
        }
        else {
            Write-Log -Message ".deleteready found in folder, or missing .wfmready, skipping $adifile" -logFile $logFile
        }
    }
