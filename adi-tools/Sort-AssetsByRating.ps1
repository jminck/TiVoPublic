
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

if ($null -eq $logFile)
{
    $logFile = ".\adiprep_$script" + (Get-Date -Format yyyy-MM-dd) + ".log"
}
if ($null -eq $folder)
{
    $folder = "/assets/vp11/Adult-SVOD" #folder to update
}

# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
$adifiles = Get-ChildItem -Recurse $folder -Filter *.xml
$c = 0
Write-Host working with folder $folder
if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null}

foreach ($adifile in $adifiles) {
    if ($confirmation -ne "a") {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
    }
    if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
        $c += 1
        Write-Host working with file $c - $adifile.FullName
        $xml = [xml](Get-Content $adifile.FullName)
        Sort-AssetsByRating -xml $xml -adifile $adifile
    }
}



