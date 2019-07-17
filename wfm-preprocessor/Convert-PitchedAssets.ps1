<#
    .SYNOPSIS
        This script is an example VOD preprocessor step prior to WFM ingest
    .DESCRIPTION
        Convert-PitchedAssets recurses through a VOD catcher share and adds TiVo VOD required ADI extensions
        to the asset metadata, as well as renaming the ADI file and its parent folder into the convention
        required by TiVO VOD
#>

# load helper functions
. .\PreprocessorFunctions.ps1

# set required variables
$catcher = "\assets\Armstrong\vp7\output\*"
[xml]$packages = Get-Content ".\packages-armstrong.xml"
$logFile = ".\preprocessor_" + (Get-Date -Format yyyy-MM-dd) + ".log"
Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Start-Transcript .\preprocessor-transcript.log
# process ADI files
$adifiles = Get-ChildItem -Recurse $catcher -Filter *.xml
foreach ($adifile in $adifiles) {
    if ((Get-ChildItem $adifile.DirectoryName -Name *.wfmready).count -gt 0) {
        # skip folders already containing a .wfmready file
        Write-Host $adifile.DirectoryName already processed
    }
    else {
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
            $xml.Save($adifile.fullname)
            $xml = [xml](Get-Content $adifile.FullName)
            if ($null -eq $isSvod)
            {
                Add-GrossNetPrice -Xml $xml -grossprice $suggestedprice -netprice $suggestedprice
                $xml.Save($adifile.fullname)
                $xml = [xml](Get-Content $adifile.FullName)            
            }
            Convert-PosterBmpToJpg -Xml $xml -adifile $adifile
            $newFolder = Rename-AssetAndFolder -Xml $xml -adifile $adifile
            Add-WfmReadyFile -folder $newFolder
            Write-Host done
            Write-Log -Message "--- finished processing $adifile" -logFile $logFile
            sleep 1
        }
    }
}
