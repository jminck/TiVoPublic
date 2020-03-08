
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
if ($null -eq $increment)
{
    $increment = 1
}
if ($null -eq $folder)
{
    $folder = "/tmp/assets/out/vp11/TVOD"
}
if ($null -eq $addcategory)
{
    $addcategory = $true
}
if ($null -eq $licensestart)
{
    $licensestart = "2020-01-01T00:00:00"
}
if ($null -eq $licenseend)
{
    $licenseend = "2030-01-01T00:00:00"
}

# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
$adifiles = Get-ChildItem -Recurse $folder -Filter *.xml
$skip = 0 #initialize
if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null} #initilize

foreach ($adifile in $adifiles) {
    if ($confirmation -ne "a") {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
    }
    if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
        $xml = [xml](Get-Content $adifile.FullName)
        $update = $false
        $skip += $increment
        $le = (get-date $licenseend).AddDays($skip)
        $le = (get-date $le -Format "yyyy-MM-ddT23:59:59")
        $leyear = (get-date $le -Format "yyyy")
        $lemonth = (get-date $le -Format "MM")
        Update-LicenseWindow -xml $xml -licensestart $licensestart -licenseend $le
        if ($addcategory) {
            $testcategory = "TiVo/ByExpiration"
            $cats = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Category']")
            foreach ($cat in $cats) {
                if ($cat.value -match $testcategory) {
                    $cat.value = "$testcategory/$leyear/$lemonth/$le" #update existing category
                    Write-Host $testcategory already exists, updating
                    $update = $true
                }
            }
            if ($update -ne $true) {
                [xml]$childnode = "<App_Data App='MOD' Name='Category' Value='" + "$testcategory/$leyear/$lemonth/$le" + "'/>"
                $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true))
            }
        }
        $xml.Save($adifile.fullname)
        Write-Host $adifile.fullname -licensestart $licensestart -licenseend $le
    }
    
}


