
<#
    .SYNOPSIS
        This script is an example VOD preprocessor step prior to WFM ingest
    .DESCRIPTION
 
#>

$script = $script:MyInvocation.MyCommand.name
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location $ScriptDir
if ($null -eq $logFile)
{
    $logFile = ".\adiprep_$script" + (Get-Date -Format yyyy-MM-dd) + ".log"
}
if ($null -eq $folder)
{
    $folder = "/mount/catcher/vp7/LK" #folder to update
}


# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
$adifiles = Get-ChildItem -Recurse $folder  -Filter *.xml
$c = 0
if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null}
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
            Set-FileAndFolderName -xml $xml -adifile $adifile
        }
        else {
            Write-Log -Message "$adifile had $xmlcount files in its folder" -logFile $logFile
        }
    }
}




