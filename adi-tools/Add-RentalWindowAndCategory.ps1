
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
    $folder = "/mount/catcher/vp15/complexoffers/40"
}
if ($null -eq $addcategory)
{
    $addcategory = $true
}
if ($null -eq $testcategory)
{
    $testcategory = "TiVo/ZVOD"
}
if ($null -eq $attribute)
{
    $attribute = $null
}

# load helper functions
. .\AdiPrepFunctions.ps1

$testcategory = "TiVo/ByRentalWindow"
$attribute = "Maximum_Viewing_Length"

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
$adifiles = Get-ChildItem -Recurse $folder -Filter *.xml
Write-Host working with folder $folder
if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null}

foreach ($adifile in $adifiles) {
    if ($confirmation -ne "a") {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
    }
    if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
        $xml = [xml](Get-Content $adifile.FullName)
        $update = $false
        if ($addcategory) {
            $cats = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Category']")
            foreach ($cat in $cats) {
                if ($cat.value -match $testcategory) {
                    if ($null -ne $attribute)
                    {
                        $window = $adifile.Directory.Parent.Parent.name + ":00:00"
                        write-host $window
                        $rentalwindow = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Maximum_Viewing_Length']")
                        $rentalwindow[0].Value =  $window
                        $cat.value = "$testcategory/" + $window #update existing category
                    } else {
                        $cat.value = "$testcategory"     
                    }
                    Write-Host $testcategory already exists, updating
                    $update = $true
                }
            }
            if ($update -ne $true) {
                if ($null -ne $attribute)
                {
                    $attrib = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$attribute']").value #update existing category
                    if ($null -eq $attrib)
                        {
                            write-host did not find attribute $attribute, aborting addition of category
                            continue #bail out
                        }
                    else {
                            $tc = "$testcategory/" + $attrib                            
                        }
                } else {
                    $tc = "$testcategory"    
                }
                [xml]$childnode = "<App_Data App='MOD' Name='Category' Value='" + $tc  + "'/>"
                $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true))
            }
        }
        
        
        $xml.Save($adifile.fullname)
        Write-Host $adifile.fullname 
    }

}


