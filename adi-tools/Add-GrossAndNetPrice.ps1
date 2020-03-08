<#
    .SYNOPSIS
       Add-GrossAndNetPrice.ps1
    .DESCRIPTION
        Add-GrossAndNetPrice.ps1 adds TiVo VOD required Gross_price and Net_price atttributes to ADI files in specified path
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
    $folder = "/tmp/assets/out/vp11/TVOD"
}
# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
Write-Host working with folder $folder logging to $logfile
Write-Log -Message "ADI files found: $adifiles" -logFile $logFile
if ($runall -eq $true){$confirmation = "a"} else{ $confirmation = $null}

$adifiles = Get-ChildItem -Recurse $folder -Filter *.xml
$c = 0
foreach ($adifile in $adifiles) {
    if ($confirmation -ne "a") {
        $confirmation = Read-Host "Are you Sure You Want To Proceed: ((y)es/(n)o/(a)ll)"
    }
    if (($confirmation -eq 'y') -or ($confirmation -eq 'a')) {
        Write-Log -Message "working with $adifile" -logFile $logFile
        $c++
        Write-Host working with file $c - $adifile.FullName
        $xml = [xml](Get-Content $adifile.FullName)
        $price = $xml.SelectNodes("//ADI/Asset/Metadata/App_Data[@Name='Suggested_Price']")
        if ($price -eq 0) { $price = "0.00" }

        $gp = $xml.SelectNodes("//App_Data") | where-object { $_.Name -match "Gross_price" }
            
        if (($gp.count -eq 0)) {
            [xml]$childnode = "<App_Data App='MOD' Name='Gross_price' Value=''/>"
            $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true)) 
            $gp = $xml.SelectNodes("//App_Data") | where-object { $_.Name -match "Gross_price" }
            $gp.value = $price.value
        }
        else {
            Write-Host "Gross_price already exists, skipping"
        }

        $np = $xml.SelectNodes("//App_Data") | where-object { $_.Name -match "Net_price" }

        if (($np.count -eq 0)) {
            [xml]$childnode = "<App_Data App='MOD' Name='Net_price' Value=''/>"
            $xml.SelectNodes("//AMS[@Asset_Class='title']").ParentNode.AppendChild($xml.ImportNode($childnode.App_Data, $true)) 
            $np = $xml.SelectNodes("//App_Data") | where-object { $_.Name -match "Net_price" }
            $np.value = $price.value
        }
        else {
            Write-Host "Net_price already exists, skipping"
        }
        $xml.Save($adifile.fullname)
        $adifile.fullname
    }
}