<#
    .SYNOPSIS
        This script is an example VOD preprocessor step prior to WFM ingest
    .DESCRIPTION
        Convert-PitchedAssets recurses through a VOD catcher share and adds TiVo VOD required ADI extensions
        to the asset metadata, as well as renaming the ADI file and its parent folder into the convention
        required by TiVO VOD
#>

$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location $ScriptDir

#load variables from config
$vars = ([xml](Get-Content ./config.xml))
$logFile = ".\preprocessor_" + (Get-Date -Format yyyy-MM-dd) + ".log"

# load helper functions
. .\PreprocessorFunctions.ps1

# set required variables
$catcher = $vars.var.catcher
[xml]$packages = Get-Content $vars.var.packages


Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
$msg = "Using variables " + ($vars.var | out-string)
Write-Log -Message $msg -logFile $logFile

# process ADI files
$adifiles = Get-ChildItem -Recurse $catcher -Filter *.xml
foreach ($adifile in $adifiles) {
    if ((Get-ChildItem $adifile.DirectoryName -Name *.wfmready).count -gt 0) {
        # skip folders already containing a .wfmready file
        Write-Host $adifile.DirectoryName already processed
    }
    else {
        Write-Log -Message "############################################################################" -logFile $logFile
        $msg = "working with folder: " + $adifile.DirectoryName
        Write-Host $msg 
        Write-Log -Message $msg  -logFile $logFile        
        $skip = (Skip-CurrentTransfers -folder $adifile.DirectoryName)
        if (!($skip[$skip.count - 1])) {

            Write-Log -Message "processing $adifile" -logFile $logFile
            # make a backup of the file
            Copy-Item $adifile.FullName ($adifile.fullname + "." + (get-date -Format yyyyMMdd) + "T" + (get-date -Format hhmmss) + ".BAK")
            # see if there are multiple XML files in the folder and log if so, we only expect one
            Get-XMLFileCount $adifile.Directory.FullName
            $xml = [xml](Get-Content $adifile.FullName)
            # copy Suggested_Price into Gross_price and Net_price (change logic for proper values per requirements if Gross/Net price are different than Suggested_Price )
            $suggestedprice = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Suggested_Price']").value
            $isSvod = Add-SvodPackage -Xml $xml -grossprice $suggestedprice -packages $packages 
            Repair-ADIErrors -Xml $xml -adifile $adifile
            $xml.Save($adifile.fullname)
            $xml = [xml](Get-Content $adifile.FullName)
            if ($null -eq $isSvod)
            {
                Add-GrossNetPrice -Xml $xml -grossprice $suggestedprice -netprice $suggestedprice
                $xml.Save($adifile.fullname)
                $xml = [xml](Get-Content $adifile.FullName)            
            }
            # ###### START workaround to remove media asset nodes when updates are pitched without media files
            # content providers are incrmenting asset versions without pitching the media assets when pitching metadata updates
            # workaround is to delete these nodes if the associated media file is not found in the asset's folder
            #
            # check for poster file in ADI, then see if the file exists in the folder
            # if file doesn't exist in the asset's folder, delete the node from the ADI file so WFM doesn't try to process a non-existent media asset
            $assettypes = @("poster","movie","preview")
            foreach ($type in $assettypes)
            {
                Write-Host "checking ADI for media asset type: $type"
                Write-Log -Message "checking ADI for media asset type: $type"  -logFile $logFile
                $assetfilename = $xml.SelectNodes( "//AMS[@Asset_Class='" + $type + "']").ParentNode.ParentNode.Content.Value
                if ($null -ne $assetfilename)
                    {
                        $msg = "media asset file name specified in ADI: $assetfilename"
                        Write-Host $msg 
                        Write-Log -Message $msg  -logFile $logFile
                        $msg = "contents of asset folder:"
                        Write-Host $msg 
                        Write-Log -Message $msg  -logFile $logFile
                        $msg = Get-ChildItem $adifile.DirectoryName | out-string
                        Write-Host $msg 
                        Write-Log -Message $msg  -logFile $logFile

                        if ((Get-ChildItem $adifile.DirectoryName -Name $assetfilename).count -eq 0) {
                            $msg =  "$assetfilename was not found in the folder " + $adifile.DirectoryName + ", removing from ADI"
                            Write-Host $msg
                            Write-Log -Message $msg  -logFile $logFile
                            $mediaasset= $xml.SelectSingleNode( "//AMS[@Asset_Class='" + $type + "']")
                            $mediaasset.ParentNode.ParentNode.ParentNode.RemoveChild($mediaasset.ParentNode.ParentNode)
                            $xml.Save($adifile.fullname)    
                        }
                    }
                else
                    {
                        $msg = "ADI did not have media asset of type $type defined, nothing to do"
                        write-host $msg
                        Write-Log -Message $msg  -logFile $logFile
                    }
            } 
            # ###### END workaround to remove media asset nodes when updates are pitched without media files
            Convert-PosterBmpToJpg -Xml $xml -adifile $adifile
            $newFolder = Rename-AssetAndFolder -Xml $xml -adifile $adifile
            if(!(Test-Path ($adifile.DirectoryPath + "/wfm-preprocessor.failure")))
            {
            Add-WfmReadyFile -folder $newFolder
            } else {
                Write-Log -Message "ERROR - wfm-preprocessor.failure exists in folder, not adding .wfmready file to folder! - see wfm-preprocessor.failure for further information, and delete wfm-preprocessor.failure if the issue has been resolved" -logFile $logFile -Severity "Error"
            }
            Write-Host done
            Write-Log -Message "--- finished processing $adifile" -logFile $logFile
            sleep 1
        }
    }
}
