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
$catcher = "/assets/wfmtest/catcher"
[xml]$packages = Get-Content "./packages2.xml"
$packageNode = "Provider_Content_Tier" #can be "Provider_Content_Tier" or "Provider", node in packages.xml to use in lookup 
$logFile = "./preprocessor_" + (Get-Date -Format yyyy-MM-dd) + ".log"


# process ADI files
$adifiles = Get-ChildItem -Recurse $catcher -Filter *.xml
foreach ($adifile in $adifiles) {
  if ((Get-ChildItem $adifile.DirectoryName -Name *.wfmready).count -gt 0) { # skip folders already containing a .wfmready file
    Write-Host $adifile.DirectoryName already processed
  }
  else {
    $skip = (Skip-CurrentTransfers -folder $adifile.DirectoryName)
    if (!($skip[$skip.count - 1]))
    {
      Write-Log -Message "processing $adifile" -logFile $logFile
      # see if there are multiple XML files in the folder and log if so, we only expect one
      Get-XMLFileCount $adifile.Directory.FullName
      $xml = [xml](Get-Content $adifile)
      # copy Suggested_Price into Gross_price and Net_price (change logic for proper values per requirements if Gross/Net price are different than Suggested_Price )
      $grossprice = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Suggested_Price']").value
      $netprice = $grossprice
      Add-GrossNetPrice -Xml $xml -grossprice $grossprice -netprice $netprice
      Add-SvodPackage -Xml $xml -grossprice $grossprice -packages $packages -packagenode $packageNode
      $newFolder = Rename-AssetAndFolder -Xml $xml -adifile $adifile
      Add-WfmReadyFile -folder $newFolder
      Write-Host done
      Write-Log -Message "--- finished processing $adifile" -logFile $logFile
    }
  }
}
