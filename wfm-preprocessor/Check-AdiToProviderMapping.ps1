
<#
    .SYNOPSIS
        This script looks in packages.xml for provider info from ADI XML files 
    .DESCRIPTION
        This script will recurse through a path looking for *.xml, and build a CSV of Provider and Profider_Content_Tier values that are missing from packages.xml
        
#>

# load helper functions
. ./PreprocessorFunctions.ps1

$logFile = "./aditoprovidermapping-" + (Get-Date -Format yyyy-MM-dd) + ".log"
$outputPath = "./missingproviders.csv"
$packages = "./packages.xml"
$providers = @()
$tiers = @()
$adifiles = Get-ChildItem -Recurse /assets/wfmtest/catcher/*.xml
Write-Log -Message "ADI files found: $adifiles.Count" -logFile $logFile
$step = $adifiles.count / 100
$pctcomplete = 0
$allassets = @()

#create output schema
$asset = New-Object System.Object
$asset | Add-Member -MemberType NoteProperty -Name Folder -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Filename -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Asset_Name  -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Title -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Provider -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Provider_Missing -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Product -Value $null
for($i = 1; $i -lt 6; $i++)
{
  $asset | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier$i -Value $null
  $asset | Add-Member -MemberType NoteProperty -Name ("Provider_Content_Tier" + $i + "_Missing") -Value $null
}
$asset | Add-Member -MemberType NoteProperty -Name Suggested_Price -Value $null
$allassets += $asset

foreach ($adifile in $adifiles) {
    $counter++
    $pexists = $false
    $logline = $false
    $xml = [xml](Get-Content $adifile)
    $asset = New-Object System.Object
    $asset | Add-Member -MemberType NoteProperty -Name Folder -Value $adifile.Directory.Name
    $asset | Add-Member -MemberType NoteProperty -Name FileName -Value $adifile.Name
    $asset | Add-Member -MemberType NoteProperty -Name Asset_Name  -Value $xml.SelectNodes("//AMS[@Asset_Class='package']").Asset_Name
    $asset | Add-Member -MemberType NoteProperty -Name Title -Value ($xml.SelectNodes("//App_Data") | Where-Object { $_.Name -eq "Title" }).Value
    $asset | Add-Member -MemberType NoteProperty -Name Provider -Value $xml.SelectNodes("//AMS[@Asset_Class='package']").Provider
    $asset | Add-Member -MemberType NoteProperty -Name Product -Value $xml.SelectNodes("//AMS[@Asset_Class='package']").Product
    $asset | Add-Member -MemberType NoteProperty -Name Suggested_Price -Value $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Suggested_Price']").value
    $tiercount = $xml.SelectNodes("//ADI/Metadata/App_Data[@Name='Provider_Content_Tier']").value.count
    $assetstr = $asset | Out-String
    if ($asset.Suggested_Price -lt 0.01) {
        Write-Log -Message "-----------------------------------------------------------------------------------------------------------------" -logFile $logFile
        Write-Log -Message "Checking asset $assetstr" -logFile $logFile
        Write-Log -Message "$adifile - Provider_Content_Tier count: $tiercount " -logFile $logFile
        $packageNode = "Provider" #can be "Provider_Content_Tier" or "Provider", node in packages.xml to use in lookup 
        $pexists = Compare-AdiToPackageXml -xml $xml -packages ([xml](Get-Content $packages)) -grossprice $asset.Suggested_Price  -packagenode $packageNode
        if ($pexists -eq $false) {
            $logline = $true
            $asset | Add-Member -MemberType NoteProperty -Name Provider_Missing  -Value $true
        }
        if ($null -ne $tiercount) {
            $tc = 0
            foreach ($tier in $xml.SelectNodes("//ADI/Metadata/App_Data[@Name='Provider_Content_Tier']").value ) {
                $packageNode = "Provider_Content_Tier" #can be "Provider_Content_Tier" or "Provider", node in packages.xml to use in lookup 
                $pexists = Compare-AdiToPackageXml -xml $xml -packages ([xml](Get-Content $packages)) -grossprice $asset.Suggested_Price  -packagenode $packageNode -tier $tier
                $tc++
                $asset | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier$tc  -Value $tier
                if ($pexists -eq $false) {
                    $logline = $true
                    $pn = "Provider_Content_Tier" + $tc + "_Missing"
                    $asset | Add-Member -MemberType NoteProperty -Name  $pn -Value $true
                }
            }
        }
        if ($logline -eq $true) { $allassets += $asset }
        if ($counter -ge $step) {
            $pctcomplete++
            Write-Progress -Activity "Search in Progress" -Status "$pctcomplete% Complete:" -PercentComplete $pctcomplete;
            $counter = 0
            Write-Host Percentage complete: $pctcomplete
        }
    } else {
      Write-Log -Message "-----------------------------------------------------------------------------------------------------------------" -logFile $logFile
      $msg = "Asset " + $asset.Folder + " - " + $asset.Asset_Name + " is not an SVOD candidate - Suggested_Price is " + $asset.Suggested_Price
      Write-Log -Message  $msg -logFile $logFile
    }
}
$allassets | Export-Csv -NoTypeInformation -Path $outputPath
Write-Host "Finished!" -ForegroundColor green
Write-host Output file: (dir $outputPath).FullName

