<#
.SYNOPSIS
Set-SampleMediaAssets.ps1
.DESCRIPTION
Set-SampleMediaAssets.ps1 sets movie, preview and poster assets to sample media assets
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
$adifiles = Get-ChildItem -Recurse $folder/*.xml



$defaultmovie = "movie_001200.ts"
$defaultmovie_FileSize = "93812376"
$defaultmovie_CheckSum = "c17fe143bf4b33755aa2b830d7e34553"
$defaultmovie_Runtime = "00:12:00"
$defaultposter = "posterart_200x150.jpg"
$defaultposter_FileSize = "16842" 
$defaultposter_CheckSum = "cea0c46b017b32d9cf384ee384c0e11a"
$defaultpreview = "preview_000200.ts"
$defaultpreview_FileSize = "15400960"
$defaultpreview_CheckSum = "43ed2bdb0ed66ef0408857338d1bada1"
$defaultpreview_Runtime = "00:02:00"

Write-Host working with folder $folder

if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null}

foreach ($adifile in $adifiles) {

    if ($confirmation -ne "a") {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
    }
    if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
        write-host "processing $adifile"
        $xml = [xml](Get-Content $adifile.FullName)
        #update movie info
        $assetname = $null
        if ($xml.SelectNodes("//AMS[@Asset_Class='movie']").count -gt 0) {
            $assetname = $xml.SelectNodes("//AMS[@Asset_Class='movie']").ParentNode.ParentNode.Content

            $assetname.Value = $defaultmovie

            $length = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Run_Time']")
            $length.Item(0).Value = $defaultmovie_Runtime
                    
            $displength = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Display_Run_Time']")
            $displength.Item(0).Value = $defaultmovie_Runtime

            $checksum = $xml.SelectNodes("//AMS[@Asset_Class='movie']").ParentNode.App_Data | Where { $_.Name -eq "Content_CheckSum" }
            $checksum.Value = $defaultmovie_CheckSum

            $filesize = $xml.SelectNodes("//AMS[@Asset_Class='movie']").ParentNode.App_Data | Where { $_.Name -eq "Content_FileSize" } 
            $filesize.Value = $defaultmovie_FileSize
        }
        else {
            Write-Host Asset $adifile.fullname did not have a movie content node
        } 

        # update preview info
        $tassetname = $null
        if ($xml.SelectNodes("//AMS[@Asset_Class='preview']").count -gt 0) {
            $tassetname = $xml.SelectNodes("//AMS[@Asset_Class='preview']").ParentNode.ParentNode.Content

            if ($tassetname) {

                $tassetname.Value = $defaultpreview

                $tlength = $xml.SelectNodes("//AMS[@Asset_Class='preview']").ParentNode.App_Data | Where { $_.Name -eq "Run_Time" }
                $tlength.Item(0).Value = $defaultpreview_Runtime

                $tchecksum = $xml.SelectNodes("//AMS[@Asset_Class='preview']").ParentNode.App_Data | Where { $_.Name -eq "Content_CheckSum" }
                $tchecksum.Value = $defaultpreview_CheckSum

                $tfilesize = $xml.SelectNodes("//AMS[@Asset_Class='preview']").ParentNode.App_Data | Where { $_.Name -eq "Content_FileSize" }    
                $tfilesize.Value = $defaultpreview_FileSize
            }
        }
        else {
            Write-Host Asset $adifile.fullname did not have a preview content node
        } 

        # update poster info
        $passetname = $null
        if ($xml.SelectNodes("//AMS[@Asset_Class='poster']").count -gt 0) {
            $passetname = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.ParentNode.Content

            $passetname.Value = $defaultposter

            $pchecksum = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.App_Data | Where { $_.Name -eq "Content_CheckSum" }
            $pchecksum.Value = $defaultposter_CheckSum

            $pfilesize = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.App_Data | Where { $_.Name -eq "Content_FileSize" }    
            $pfilesize.Value = $defaultposter_FileSize
        
        }
        else {
            Write-Host Asset $adifile.fullname did not have a poster content node
        } 
   
        $xml.Save($adifile)
        Write-Host Saved $adifile
    }
}
     