

<#
    .SYNOPSIS
        This script is an example VOD preprocessor step prior to WFM ingest
    .DESCRIPTION
 
#>

$script = $script:MyInvocation.MyCommand.name
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location $ScriptDir
$logFile = ".\adiprep_$script" + (Get-Date -Format yyyy-MM-dd) + ".log"

$folder = "/mount/catcher/vp12/v3/complexoffers"

# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
$adifiles = Get-ChildItem -Recurse $folder -Filter *.xml
if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null}

foreach ($adifile in $adifiles)
    {
        write-host "processing $adifile"
        if ($confirmation -ne "a")
        {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
        }
        if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
            $xml = [xml](Get-Content $adifile)

            #rev version number
            [int]$version = $xml.ADI.Metadata.AMS.Version_Major
            $version++
            $props = $xml.SelectNodes("//AMS") 
            foreach ($vmaj in $props) {$vmaj.SetAttribute("Version_Major",$version)}
            $xml.Save($adifile)
            $assetid = $xml.SelectNodes("//AMS[@Asset_Class='title']").Asset_ID
            $timestamp = (get-date -Format yyyyMMdd) + "T" + (get-date -Format HHmmss) + "Z"
            $newfolder = $assetid + "-" + $timestamp 
            $folder = $adifile.directoryname
            rename-item $folder $newfolder  
            start-sleep -Milliseconds 100   
            Write-host $newfolder.directoryname
        }
    }
  