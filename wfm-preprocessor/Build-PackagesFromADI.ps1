
<#
    .SYNOPSIS
        This script builds packages.xml from a path containing ADI XML files 
    .DESCRIPTION
        This script will recurse through a path looking for *.xml, extract prodiver names and Provider_Content_Tier
        elements from the fils, and build a packages.xml file
        
        <Assets>
          <Provider_Content_Tier>
            <Tier>
              <Name>basic</Name>
              <Providers>
                <Provider>ABC</Provider>
              </Providers>
              <Provider_Content_Tiers>
                <Provider_Content_Tier>ADULTSWIM_15</Provider_Content_Tier>
              </Provider_Content_Tiers>
            </Tier>
          </Provider_Content_Tier>
        </Assets>

#>

# load helper functions
. ./PreprocessorFunctions.ps1

$logFile = "./packages-" + (Get-Date -Format yyyy-MM-dd) + ".log"
$outputPath = "./packages.xml"
$providers = @()
$tiers = @()
$adifiles = Get-ChildItem -Recurse /assets/wfmtest/catcher/*.xml
Write-Log -Message "ADI files found: $adifiles.Count" -logFile $logFile
$step = $adifiles.count / 100
$i = 0
foreach ($adifile in $adifiles) {
  $counter++
  $xml = [xml](Get-Content $adifile)
  $providers += $xml.SelectNodes("//AMS[@Asset_Class='package']").Provider
  $tiers += $xml.SelectNodes("//ADI/Metadata/App_Data[@Name='Provider_Content_Tier']").value
  Write-Log -Message "Scanning $adifile" -logFile $logFile
  $p = $xml.SelectNodes("//AMS[@Asset_Class='package']").Provider
  Write-Log -Message "Provider name is $p" -logFile $logFile
  $p = $xml.SelectNodes("//AMS[@Asset_Class='package']").Asset_Name
  Write-Log -Message "Asset_name is $p" -logFile $logFile
  $p = $xml.SelectNodes("//ADI/Metadata/App_Data[@Name='Provider_Content_Tier']").value
  if ($null -eq $p)
  { $sev = "warning" }
  else
  { $sev = "Information" }
  Write-Log -Message "Provider_Content_Tier is $p" -logFile $logFile -Severity $sev
  if ($counter -ge $step) {
    Write-Progress -Activity "Search in Progress" -Status "$i% Complete:" -PercentComplete $i;
    $counter = 0
    $i++
  }
}

$providers = $providers | Sort-Object -Unique
$tiers = $tiers | Sort-Object -Unique
Write-Host "Initializing new XML document" -ForegroundColor Green
[xml]$Doc = New-Object System.Xml.XmlDocument

#create declaration
$dec = $Doc.CreateXmlDeclaration("1.0","UTF-8",$null)
#append to document
$doc.AppendChild($dec) | Out-Null

#create a comment and append it in one line
$text = "
    ADI providers and Provider_Content_Tier export
    Generated $(Get-Date)
    "

$doc.AppendChild($doc.CreateComment($text)) | Out-Null

#create root Node
$root = $doc.CreateNode("element","Assets",$null)
$pct = $doc.CreateNode("element","Tiers",$null)
$tiernode = $doc.CreateNode("element","Tier",$null)
$tiername = $doc.CreateNode("element","Name",$null)
$tiername.InnerText = "basic"
$tiernode.AppendChild($tiername) | Out-Null

#create an element
$provider_node = $doc.CreateNode("element","Providers",$null)
#assign a value
foreach ($provider in $providers) {
  $pvd = $doc.CreateElement("Provider")
  $pvd.InnerText = $provider
  $provider_node.AppendChild($pvd) | Out-Null
}

$content_tier_node = $doc.CreateNode("element","Provider_Content_Tiers",$null)
#assign a value
foreach ($tier in $tiers) {
  $t_node = $doc.CreateElement("Provider_Content_Tier")
  $t_node.InnerText = $tier
  $content_tier_node.AppendChild($t_node) | Out-Null
}

#add to parent node
$tiernode.AppendChild($provider_node) | Out-Null

$tiernode.AppendChild($content_tier_node) | Out-Null

#add to parent node
$pct.AppendChild($tiernode) | Out-Null

#append to root
$root.AppendChild($pct) | Out-Null
#foreach computer

#add root to the document
$doc.AppendChild($root) | Out-Null
#save file
Write-Host "Saving the XML document to $outputPath" -ForegroundColor Green
$doc.Save($outputPath)

Write-Host "Finished!" -ForegroundColor green
