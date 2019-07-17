
<#
    .SYNOPSIS
        This script sets the delete verb for pitching an asset deletion
    .DESCRIPTION
        This script sets the delete verb for pitching an asset deletion, and update the asset's folder name with "delete_" and a new timestamp
        to allow the asset to be removed from the TiVo VOD system.
#>

# load helper functions
. ./PreprocessorFunctions.ps1

$logFile = "./setassetdeleteverb-" + (Get-Date -Format yyyy-MM-dd) + ".log"
$adifiles = Get-ChildItem -Recurse "/assets/Armstrong/catcher/Dropbox/9*" -Include *.xml
Write-Log -Message "ADI files found: $adifiles" -logFile $logFile

$confirmation = $null

foreach ($adifile in $adifiles) {
    write-host "processing $adifile"
    if ($confirmation -ne "a") {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
    }
    if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
        Write-Log -Message "working with $adifile" -logFile $logFile
        $xml = [xml](Get-Content $adifile)
        #rev version number
        [int]$version = $xml.ADI.Metadata.AMS.Version_Major
        $version++
        $props = $xml.SelectNodes("//AMS") 
        foreach ($vmaj in $props) { 
            $vmaj.SetAttribute("Verb", "DELETE") 
        }
        $xml.Save($adifile)
        $assetid = $xml.SelectNodes("//AMS[@Asset_Class='title']").Asset_ID
        $timestamp = (get-date -Format yyyyMMdd) + "T" + (get-date -Format hhmmss) + "Z"
        $newfolder = "delete_" + $assetid + "_" + $timestamp 
        $folder = $adifile.directoryname
        #add wfmready file if missing
        $wfmreadyfile = $adifile.DirectoryName + "/" + $adifile.Name.toupper().Replace(".XML", ".wfmready")
        if (!(Test-Path $wfmreadyfile)) { 
            New-Item $wfmreadyfile -ItemType File
        }
        rename-item $folder $newfolder  
        start-sleep -Milliseconds 100      
    }
}
