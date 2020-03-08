
<#
    .SYNOPSIS
        This script is an example VOD preprocessor step prior to WFM ingest
    .DESCRIPTION
 
#>

$script = $script:MyInvocation.MyCommand.name
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$logFile = ".\adiprep_$script" + (Get-Date -Format yyyy-MM-dd) + ".log"

$folder = "/tmp/assets/NOTYPE" #folder to update
$removecategory = $true

# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
$adifiles = Get-ChildItem -Recurse $folder -Filter *.xml
Write-Host working with folder $folder
if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null}

$c = 0
foreach ($adifile in $adifiles) {
    if ($confirmation -ne "a") {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
    }
    if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
        $c++
        Write-Host working with file $c - $adifile.FullName
        $xml = [xml](Get-Content $adifile.FullName)
        #remove SVOD packages
        $v_svodpackage = $xml.ADI.Asset.Metadata.App_Data | Where-Object { $_.Name -eq "Package_offer_ID" }
        if ($v_svodpackage.count -gt 1) {
            Write-Log -Message "Found multiple SVOD packages" -logFile $logFilea
            for ($i = 1; $i -lt $v_svodpackage.count; $i++) {
                $v = $v_svodpackage[$i]
                Write-Log -Message "removing SVOD package $v.value" -logFile $logFile
                $v.ParentNode.RemoveChild($v)
            }
        }
        else {
            $v_svodpackage.ParentNode.RemoveChild($v_svodpackage)
        }
    
        if ($removecategory) {
            $testcategory = "TiVo/SVOD"
            $cats = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Category']")
            foreach ($cat in $cats) {
                if ($cat.value -match $testcategory) {
                    $cat.ParentNode.RemoveChild($cat)
                }
            }
        }
        $xml.Save($adifile.fullname)
        $adifile.fullname
    }
}



