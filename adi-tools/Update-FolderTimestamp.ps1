
<#
    .SYNOPSIS
        This script is an example VOD preprocessor step prior to WFM ingest
    .DESCRIPTION
        Convert-PitchedAssets recurses through a VOD catcher share and adds TiVo VOD required ADI extensions
        to the asset metadata, as well as renaming the ADI file and its parent folder into the convention
        required by TiVO VOD
#>

$script = $script:MyInvocation.MyCommand.name
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$logFile = ".\adiprep_$script" + (Get-Date -Format yyyy-MM-dd) + ".log"

$folderpath = "/assets/catcher/vp11/redo2" #folder to update

# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
$adifiles = Get-ChildItem -Recurse $folderpath  -Filter *.xml -exclude done/*
$c = 0
$confirmation = "a"
Write-host file coount $adifiles.count
foreach ($adifile in $adifiles) {
    write-host "processing $adifile"
    if ($confirmation -ne "a") {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
    }
    if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
        $c += 1
        Write-Host working with file $c - $adifile.FullName
        $xml = [xml](Get-Content $adifile.FullName)
        $xmlcount = Get-XMLFileCount $adifile.Directory.FullName
        if ($xmlcount -eq 1) {
            Set-FileAndFolderName -xml $xml -adifile $adifile -folderonly $true
        }
        else {
            Write-Log -Message "$adifile had $xmlcount files in its folder" -logFile $logFile
        }
    }
}




