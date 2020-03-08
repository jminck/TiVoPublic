
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
    $folder = "/tmp/assets/out/vp11/TVOD"
}
if ($null -eq $addcategory)
{
    $addcategory = $true
}

# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
Write-Host working with folder $folder
if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null}
$adifiles = Get-ChildItem -Recurse $folder -Filter *.xml
$tricks = "FF", "FF,RW,Pause", "FF,RW", "FF,Pause", "RW,Pause", "RW", "Pause"
$c = 0
foreach ($adifile in $adifiles) {
    if ($confirmation -ne "a") {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
    }
    if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
        $update = $false
        $c += 1
        Write-Host working with file $c - $adifile.FullName
        $xml = [xml](Get-Content $adifile.FullName)
        $restrictions = $xml.SelectNodes("//ADI/Asset/Asset/Metadata/App_Data[@Name='trickModesRestricted']")
        if ($restrictions.count -gt 1)
        { Write-Host ERROR, multiple trickModesRestricted nodes detected }

        $trick = Get-Random $tricks

        if ($restrictions.count -eq 0) {
            [xml]$childnode = "<App_Data App='MOD' Name='trickModesRestricted' Value='" + "$trick" + "'/>"
            $xml.SelectNodes("//AMS[@Asset_Class='movie']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true))
        }
        else {
            $restrictions.SetAttribute("Value", $trick)
        }

        if ($addcategory) {
            $testcategory = "TiVo/TrickRestrictions"
            $cats = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Category']")
            foreach ($cat in $cats) {
                if ($cat.value -match $testcategory) {
                    $cat.value = "$testcategory/$trick" #update existing category
                    Write-Host $testcategory already exists, updating
                    $update = $true
                }
            }
            if ($update -ne $true) {
                [xml]$childnode = "<App_Data App='MOD' Name='Category' Value='" + "$testcategory/$trick" + "'/>"
                $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true))
            }
        }
    
        $xml.Save($adifile.fullname)
        $adifile.fullname
    }
}



