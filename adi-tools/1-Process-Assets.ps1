#
# This is a wrapper around other scripts to drive an asset processing workflow.
#

# $runall is a global to set $confirmation = "a" in each script to run every step without prompts
$runall = $true

$starttime = Get-Date
$logFile = ".\Process-Assets-" + (Get-Date -Format yyyy-MM-dd) + ".log"


########
# Create-FolderStructure.ps1
# This script takes multiple ADI XML files in the same folder and separates them into individual subfolders
# This would be used if you had a ZIP file of a dump of ADIs, all in a single folder, in order to create a folder per asset
# Relies on:
# $logFile (optional - will default to default name)
# $inputpath = "/assets/vp11/deletes/vp11" #folder to process
# $outputpath = "/assets/vp11/deletes/vp11/out" #folder to output structure to
$inputpath = "/assets/scratch/test" 
$outputpath = "/assets/scratch/test/out_v1"
Write-Host calling ./Create-FolderStructure.ps1
./Create-FolderStructure.ps1

########
# Set-FileAndFolderName.ps1
# This script renames the ADI file to its asset ID, and the folder name to TiVo VOD required name <asset_id>-<timestampe>
# Relies on:
# $logFile (optional - will default to default name)
# $folder - the root folder containing asset subfolders with ADI files
$folder = $outputpath 
Write-Host calling ./Set-FileAndFolderName.ps1
./Set-FileAndFolderName.ps1

# When Calling sort functions, call least specific (type, rating) before more specific (series)

########
# Sort-AssetsByType.ps1
# This script sorts the folder structure of assets by type (ZVOD/SVOD/TVOD) based on information in the ADI file
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
Write-Host calling ./Sort-AssetsByType.ps1
./Sort-AssetsByType.ps1

########
# Sort-AssetsByRating.ps1
# This script sorts the folder structure of assets by Rating
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
# Write-Host calling ./Sort-AssetsByRating.ps1
# ./Sort-AssetsByRating.ps1

########
# Sort-AssetsBySeries.ps1
# This script (attempts to) sort the folder structure of assets by series
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
Write-Host calling ./Sort-AssetsBySeries.ps1
./Sort-AssetsBySeries.ps1

########
# Set-SampleMediaAssets.ps1
# This script updates the movie, preview and poster assets in the ADI file with hardcoded values from a sample public domain movie
# Values applied are from the following assets:
# "movie_001200.ts"
# "posterart_200x150.jpg"
# "preview_000200.ts"
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
$folder = $outputpath 
Write-Host calling Set-SampleMediaAssets.ps1
Set-SampleMediaAssets.ps1

########
# Add-GrossAndNetPrice.ps1
# This script reads Suggested_Price element from ADI and sets TiVo VOD required attributes Gross_price and Net_price to the same value
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
Write-Host calling ./Add-GrossAndNetPrice.ps1
./Add-GrossAndNetPrice.ps1

########
# Update-LicenseWindow.ps1
# This script sets Licensing_Window_Start and Licensing_Window_End
# optionally, will incrment Licensing_Window_End for each asset processed by $increment
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
# $addcategory $true by default
# $licensestart = "2020-01-01T00:00:00"
# $licenseend = "2030-01-01T00:00:00"
# $increment = <int> - number of days to incrment expiration date from one asset to the next, to create a series of expirations over time
$licensestart = "2020-01-01T00:00:00"
$licenseend = "2030-01-01T00:00:00"
$increment = 0 
Write-Host calling ./Update-LicenseWindow.ps1
./Update-LicenseWindow.ps1

########
# Add-SvodPackage.ps1
# This script sets Package_offer_ID attribute to the value specified by $packagename
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
# $addcategory $true by default
# $packagename
$packagename = "super-svod"
Write-Host calling ./Add-SvodPackage.ps1
./Add-SvodPackage.ps1

########
# Add-OutOfHomeRestrictions.ps1
# This script sets 'Restricted_Location_Types' atrtibute to 'OUT_OF_HOME'
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
# $addcategory $true by default
$folder = "/assets/scratch/test/out_v1/TVOD/NCIS"
Write-Host calling ./Add-OutOfHomeRestrictions.ps1
./Add-OutOfHomeRestrictions.ps1

########
# Add-TrickPlayRestrictions.ps1
# this script sets random trickplay restrictions to each asset from the array "FF", "FF,RW,Pause", "FF,RW", "FF,Pause", "RW,Pause", "RW", "Pause"
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
# $addcategory $true by default
$folder = "/assets/scratch/test/out_v1/TVOD/Twin Peaks"
Write-Host calling ./Add-TrickPlayRestrictions.ps1
./Add-TrickPlayRestrictions.ps1

########
# Add-TivoCategory.ps1
# This script adds a category to the ADI  based on $testcategory
# optionally, if $attribute is set, the attribute's value in the ADI will be added to the category name
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
# $addcategory $true by default
# $attribute - (optional) set if you want to pull an attribute from title node of the ADI file, like Rating 
$folder = "/assets/scratch/test/out_v1"
$testcategory = "TiVo/ByRating"
$attribute = "Rating"
Write-Host calling ./Add-TivoCategory.ps1
./Add-TivoCategory.ps1


########
# Add-WfmReadyFile.ps1
# This script adds wfmready file to each folder to signal that the asset is ready for processing by WFM
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
Write-Host calling ./Add-WfmReadyFile.ps1
./Add-WfmReadyFile.ps1

########
# Export-AssetInfoToCsv.ps1
# This script dumps ADI and folder info to a CSV file for convenience and asset attribute documentation
# Relies on:
# $logFile (optional - will default to default name)
# $folder 
./Export-AssetInfoToCsv.ps1

Write-host Start Time: $starttime
$endtime = Get-Date
Write-host End Time: $endtime