<#
    .SYNOPSIS
        This script is an example VOD preprocessor step prior to WFM ingest
    .DESCRIPTION
        Convert-PitchedAssets recurses through a VOD catcher share and adds TiVo VOD required ADI extensions
        to the asset metadata, as well as renaming the ADI file and its parent folder into the convention
        required by TiVO VOD
#>

# load helper functions
. ./PreprocessorFunctions.ps1

# set required variables
$adifiles = dir -Recurse /assets/arm2/*.xml
$logFile = "./preprocessor_" + (get-date -Format yyyy-MM-dd) + ".log"
[xml]$packages = Get-Content "/assets/TDS-ADI/wfm-preprpocessor/packages.xml"

# process ADI files
foreach ($adifile in $adifiles) {
    if ((get-ChildItem  $adifile.DirectoryName -Name *.wfmready).count -gt 0) { # skip folders already containing a .wfmready file
        Write-host $adifile.DirectoryName already processed
    }
    else {
        Write-Log -Message "processing $adifile" -logFile $logFile
        $xml = [xml](Get-Content $adifile)
        # copy Suggested_Price into Gross_price and Net_price (change logic for proper values per requirements if Gross/Net price are different than Suggested_Price )
        $grossprice = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Suggested_Price']").value 
        $netprice = $grossprice 
        Add-GrossNetPrice -xml $xml -grossprice $grossprice -netprice $netprice
        Add-SvodPackage -xml $xml -grossprice $grossprice -packages $packages
        $newFolder = Rename-AssetAndFolder -xml $xml -adifile $adifile
        Add-WfmReadyFile -folder $newFolder
        write-host done
        Write-Log -Message "--- finished processing $adifile" -logFile $logFile
    }
}
