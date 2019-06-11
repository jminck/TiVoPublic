
<#
    .SYNOPSIS
        This script builds provider info from ADI XML files 
    .DESCRIPTION
        This script will recurse through a path looking for *.xml, and build a CSV file of all assets, Provider and Profider_Content_Tier values
        
#>

# load helper functions
. ./PreprocessorFunctions.ps1

$logFile = "./assetproviderinfo-" + (Get-Date -Format yyyy-MM-dd) + ".log"
$outputPath = "./assetproviderinfo.csv"
$providers = @()
$tiers = @()
$adifiles = Get-ChildItem -Recurse /assets/TDS-ADI/ADI/*.xml
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
$asset | Add-Member -MemberType NoteProperty -Name Product -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier1 -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier2 -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier3 -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier4 -Value $null
$asset | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier5 -Value $null
$allassets += $asset

foreach ($adifile in $adifiles) {
  $counter++
  $xml = [xml](Get-Content $adifile)
    $asset = New-Object System.Object
    $asset | Add-Member -MemberType NoteProperty -Name Folder -Value $adifile.Directory.Name
    $asset | Add-Member -MemberType NoteProperty -Name FileName -Value $adifile.Name
    $asset | Add-Member -MemberType NoteProperty -Name Asset_Name  -Value $xml.SelectNodes("//AMS[@Asset_Class='package']").Asset_Name
    $asset | Add-Member -MemberType NoteProperty -Name Title -Value ($xml.SelectNodes("//App_Data") | Where-Object { $_.Name -eq "Title" }).Value
    $asset | Add-Member -MemberType NoteProperty -Name Provider -Value $xml.SelectNodes("//AMS[@Asset_Class='package']").Provider
    $asset | Add-Member -MemberType NoteProperty -Name Product -Value $xml.SelectNodes("//AMS[@Asset_Class='package']").Product
    $tiercount = $xml.SelectNodes("//ADI/Metadata/App_Data[@Name='Provider_Content_Tier']").value.count
    Write-Log -Message "$adifile - Provider_Content_Tier count: $tiercount " -logFile $logFile
    if($null -ne $tiercount)
        {
        $tc = 0
        foreach($tier in $xml.SelectNodes("//ADI/Metadata/App_Data[@Name='Provider_Content_Tier']").value )
        {
            $tc++
            $asset | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier$tc  -Value $tier
        }
    }
    $allassets += $asset
  
  if ($counter -ge $step) {
    $pctcomplete++
    Write-Progress -Activity "Search in Progress" -Status "$pctcomplete% Complete:" -PercentComplete $pctcomplete;
    $counter = 0
    Write-Host Percentage complete: $pctcomplete
  }
}

$allassets |  Export-Csv -NoTypeInformation -Path $outputPath
Write-Host "Finished!" -ForegroundColor green
