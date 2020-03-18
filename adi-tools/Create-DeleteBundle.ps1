
<#
    .SYNOPSIS
        This script sets the delete verb for pitching an asset deletion
    .DESCRIPTION
        This script sets the delete verb for pitching an asset deletion, and update the asset's folder name with "delete_" and a new timestamp
        to allow the asset to be removed from the TiVo VOD system.
#>

# load helper functions

$script = $script:MyInvocation.MyCommand.name
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$logFile = ".\adiprep_$script" + (Get-Date -Format yyyy-MM-dd) + ".log"

$inputpath = "/mount/catcher/vp11/DELETE_v2/USA-BRAVO-cleanup_v2" #folder to update
$outputpath = "$inputpath/DELETE"

# load helper functions
. .\AdiPrepFunctions.ps1

$adifiles = Get-ChildItem -Recurse $inputpath  -Filter *.xml

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile

Write-Host working with folder $inputpath
Write-Log -Message "ADI files found: $adifiles" -logFile $logFile
if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null}

if (!(Test-Path $outputpath)) {New-Item $outputpath -Type Directory}

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
        
        $assetid = $xml.SelectNodes("//AMS[@Asset_Class='title']").Asset_ID
        $timestamp = (get-date -Format yyyyMMdd) + "T" + (get-date -Format hhmmss) + "Z"
        $newfolder = $outputpath + "/delete_" + $assetid + "-" + $timestamp 
        Write-Host $newfolder
        if (!(Test-Path $newfolder)) {New-Item $newfolder -Type Directory}
        #add wfmready file if missing
        $wfmreadyfile = $newfolder + "/" + $adifile.Name.toupper().Replace(".XML", ".wfmready")
        Write-Host $wfmreadyfile
        if (!(Test-Path $wfmreadyfile)) { 
            New-Item $wfmreadyfile -ItemType File
        }
        $newfile = ($newfolder + "/" + $adifile.Name)
        Write-Host $newfile
        $xml.Save($newfile)
        Write-Host --------- 
    }
}
