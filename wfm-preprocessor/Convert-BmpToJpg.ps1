
<#
    .SYNOPSIS
        This script converts BMP poster art to JPG and udpates ADI file
    .DESCRIPTION
        This script converts BMP poster art to JPG and udpates ADI file properties Content_FileSize and Content_CheckSum as well as the Content node
        containing the new file name

        This script depends on ImageMagick to be installed https://imagemagick.org
#>

# load helper functions
. ./PreprocessorFunctions.ps1

$logFile = "./convert-bmptojpg-" + (Get-Date -Format yyyy-MM-dd) + ".log"
$adifiles = Get-ChildItem -Recurse /assets/wfmtest/bmp/*.xml
Write-Log -Message "ADI files found: $adifiles.Count" -logFile $logFile


if($null -ne (Get-Command "convert" -ErrorAction SilentlyContinue))
    {
        $magic = $null
    }
    elseif($null -ne (Get-Command "magick" -ErrorAction SilentlyContinue))
    {
        $magic = "magick"
    }
    else
    {
        Write-Log -Message "This script depends on ImageMagick to be installed https://imagemagick.org" -logFile $logFile
        Throw "This script depends on ImageMagick to be installed https://imagemagick.org"
    }

$confirmation = $null

foreach ($adifile in $adifiles)
    {
        write-host "processing $adifile"
        if ($confirmation -ne "a") #we said "all" when prompted to continue
        {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
        }
        if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
            $xml = [xml](Get-Content $adifile)

            if ($xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.ParentNode.Content.Value -like "*bmp")
            {
                $passetname = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.ParentNode.Content
    
                $bmppath = $adifile.DirectoryName + "/" + $passetname.value
                $jpgpath = $bmppath.Replace(".bmp",".jpg")

                if ($null -eq $magic)
                {
                    $result = convert -verbose $bmppath $jpgpath #needs ImageMagick installed
                } else {
                    $result = magic convert -verbose $bmppath $jpgpath #needs ImageMagick installed
                }

                Write-log -Message "processing $adifile.FullName" -logFile $logFile 
                Write-log -Message "converting $bmppath" -logFile $logFile 
                Write-log -Message "convert output: $result" -logFile $logFile 
                if (Test-Path $jpgpath) 
                {
                    $jpg = get-item $jpgpath
                    $md5 = (Get-FileHash -Algorithm MD5 $jpg.FullName).hash
                    $filesize = $jpg.Length
                }

                $passetname.value = $jpg.name
                $pchecksum = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.App_Data | Where {$_.Name -eq "Content_CheckSum" }
                $pchecksum.Value = $md5
                $pfilesize = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.App_Data | Where {$_.Name -eq "Content_FileSize" }    
                $pfilesize.Value = $filesize
                if ($magic = $null)
                {
                    $dimensions = identify -ping -format "%w x %h" $jpg.FullName
                } else {
                    $dimensions = magick identify -ping -format "%w x %h" $jpg.FullName
                }
                $pdimensions = $xml.SelectNodes("//AMS[@Asset_Class='poster']").ParentNode.App_Data | Where { $_.Name -eq "Image_Aspect_Ratio" }    
                $pdimensions.Value = $dimensions.Replace(" ", "")
                $xml.Save($adifile.fullname)
            }
            else
                {
                    Write-Host Asset $adifile.fullname did not have a poster node with a .bmp
                    Write-log -Message "$adifile.fullname did not have a poster node with a .bmp" -logFile $logFile 
                } 
        }
    }
