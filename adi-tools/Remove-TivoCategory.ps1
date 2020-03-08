
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

$folder = "/assets/catcher/vp11/v2"

$removecategory = $true

# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
$adifiles = Get-ChildItem -Recurse $folder -Filter *.xml
$skip = 0 #initialize
Write-Host working with folder $folder
if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null}

foreach ($adifile in $adifiles) {
    if ($confirmation -ne "a") {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
    }
    if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
        $xml = [xml](Get-Content $adifile.FullName)
 
        if ($removecategory) {
            $testcategory = "Short Expiration"
            $cats = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Category']")
            foreach ($cat in $cats) {
                if ($cat.value -match $testcategory) {
                    Write-Log -Message "removing category $testcategory" -logFile $logFile
                    $cat.ParentNode.RemoveChild($cat)
                }
            }
        }
        $xml.Save($adifile.fullname)
    }
}


