
<#
    .SYNOPSIS
        This script is an example VOD preprocessor step prior to WFM ingest
    .DESCRIPTION
 
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
    $folder = "/Users/jminckler/OneDrive/TiVo/Armstrong/wfmlogs/adi/home/deploy/adi"
}

$outputfile = $folder + "/" + ($folder.replace("/",".") + "-assets-" + (Get-Date -Format yyyy-MM-dd-HH-mm-ss) + ".CSV").TrimStart(".")

# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
$adifiles = Get-ChildItem -Recurse $folder -Filter *.xml
$c = 0
$csvContents = @() # Create the empty array that will eventually be the CSV file

foreach ($adifile in $adifiles) 
    {
        $c++
        $row = New-Object System.Object # Create an object to append to the array
         Write-Host working with file $c - $adifile.FullName
        $xml = [xml](Get-Content $adifile.FullName)

        $element = "Asset_ID"
        $v = $xml.SelectNodes("//AMS[@Asset_Class='title']").$element
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "Provider"
        $v = $xml.SelectNodes("//AMS[@Asset_Class='title']").$element
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "Provider_ID"
        $v = $xml.SelectNodes("//AMS[@Asset_Class='title']").$element
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "Title"
        $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "Available_in_Localities"
        $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v
        
        $element = "Gross_price"
        $prices = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']")
        $v = $null
        if ($prices.count -gt 1)
        {
            foreach ($price in $prices)
            {$v = $v + " | " + $price.value + " " + $price.Locality}
            $v = $v + " | "
        } else {
            $v = $prices.Value 
        }  
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "Net_price"
        $prices = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']")
        $v = $null
        if ($prices.count -gt 1)
        {
            foreach ($price in $prices)
            {$v = $v + " | " + $price.value + " " + $price.Locality}
            $v = $v + " | "
        } else {
            $v = $prices.Value 
        }  
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v
        
        $element = "Package_offer_ID"
        $pkgs = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']")
        $v = $null
        if ($pkgs.count -gt 1)
        {
            foreach ($pkg in $pkgs)
            {$v = $v + " | " + $pkg.value + " " + $pkg.Locality}
            $v = $v + " | "
        } else {
            $v = $pkgs.Value 
        }        
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "Category"
        $v = $null
        $cats = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
        if ($cats.count -gt 1)
        {
            foreach ($cat in $cats)
            {$v = $v + " | " + $cat}
            $v = $v + " | "
        } else {
            $v = $cats
        }
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "Rating"
        $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "trickModesRestricted"
        $v = $xml.SelectNodes("//ADI/Asset/Asset/Metadata/App_Data[@Name='$element']").value
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "Restricted_Location_Types"
        $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "Licensing_Window_Start"
        $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v
        
        $element = "Licensing_Window_End"
        $v = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='$element']").value
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        $element = "AssetFolder"
        $v = $adifile.DirectoryName
        Write-Host $element - $v
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value $v

        #create empty field, filled in later
        $element = "Dupe"
        $row | Add-Member -MemberType NoteProperty -Name "$element" -Value ""

        Write-Host "------------------------------------------------------------------"
        if ($null -ne $row.Asset_ID)
        {
            $csvContents += $row # append the new data to the array
        }

    }
    
Write-Host looking for duplicate assets
$csvContents = $csvContents | Sort-Object -Property Asset_ID
for ($i = 0; $i -lt ($csvContents.Asset_ID.count - 1); $i++)
    {
        Write-Host comparing $csvContents[$i].Asset_ID to $csvContents[$i+1].Asset_ID
        if ($csvContents[$i].Asset_ID -eq $csvContents[$i+1].Asset_ID)
        {
            write-host dupe: $csvContents[$i].Asset_ID 
            write-host  path: $csvContents[$i].AssetFolder
            write-host  path: $csvContents[$i+1].AssetFolder
            $csvContents[$i].Dupe = "True"
            $csvContents[$i+1].Dupe = "True"
        }
    }


$csvContents | Export-CSV -Path $outputfile