
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
$adifiles = Get-ChildItem -Recurse /assets/wfmtest/catcher/*.xml
Write-Log -Message "ADI files found: $adifiles.Count" -logFile $logFile
$step = $adifiles.count / 100
$AllAssets = @()

#create output schema
$RCObject = New-Object System.Object
$RCObject | Add-Member -MemberType NoteProperty -Name Folder -Value $null
$RCObject | Add-Member -MemberType NoteProperty -Name Asset_Name  -Value $null
$RCObject | Add-Member -MemberType NoteProperty -Name Title -Value $null
$RCObject | Add-Member -MemberType NoteProperty -Name Provider -Value $null
$RCObject | Add-Member -MemberType NoteProperty -Name Product -Value $null
$RCObject | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier1 -Value $null
$RCObject | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier2 -Value $null
$RCObject | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier3 -Value $null
$RCObject | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier4 -Value $null
$RCObject | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier5 -Value $null
$AllAssets += $RCObject

foreach ($adifile in $adifiles) {
  $counter++
  $xml = [xml](Get-Content $adifile)
    $RCObject = New-Object System.Object
    $RCObject | Add-Member -MemberType NoteProperty -Name Folder -Value $adifile.Directory.Name
    $RCObject | Add-Member -MemberType NoteProperty -Name Asset_Name  -Value $xml.SelectNodes("//AMS[@Asset_Class='package']").Asset_Name
    $RCObject | Add-Member -MemberType NoteProperty -Name Title -Value ($xml.SelectNodes("//App_Data") | Where-Object { $_.Name -eq "Title" }).Value
    $RCObject | Add-Member -MemberType NoteProperty -Name Provider -Value $xml.SelectNodes("//AMS[@Asset_Class='package']").Provider
    $RCObject | Add-Member -MemberType NoteProperty -Name Product -Value $xml.SelectNodes("//AMS[@Asset_Class='package']").Product
    $tiercount = $xml.SelectNodes("//ADI/Metadata/App_Data[@Name='Provider_Content_Tier']").value.count
    Write-Log -Message "$adifile - Provider_Content_Tier count: $tiercount " -logFile $logFile
    if($null -ne $tiercount)
        {
        $i = 0
        foreach($tier in $xml.SelectNodes("//ADI/Metadata/App_Data[@Name='Provider_Content_Tier']").value )
        {
            $i++
            $RCObject | Add-Member -MemberType NoteProperty -Name Provider_Content_Tier$i  -Value $tier
        }
    }
    $AllAssets += $RCObject
  }
  if ($counter -ge $step) {
    Write-Progress -Activity "Search in Progress" -Status "$i% Complete:" -PercentComplete $i;
    $counter = 0
    Write-Host Percentage complete: $i
    $i++
  }

$allAssets |  Export-Csv -NoTypeInformation -Path $outputPath
Write-Host "Finished!" -ForegroundColor green
