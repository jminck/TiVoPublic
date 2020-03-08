
<#
    .SYNOPSIS
        This script takes multiple ADI XML files in the same folder and separates them into individual subfolders
    .DESCRIPTION
        This script takes multiple ADI XML files in the same folder and separates them into individual subfolders
#>

$script = $script:MyInvocation.MyCommand.name
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location $ScriptDir

if ($null -eq $logFile)
{
    $logFile = ".\adiprep_$script" + (Get-Date -Format yyyy-MM-dd) + ".log"
}
if ($null -eq $inputpath)
{
    $inputpath = "/assets/vp11/deletes/vp11" #folder to update
}
if ($null -eq $inputpath)
{
    $outputpath = "/assets/vp11/deletes/vp11/out"
}


# load helper functions
. .\AdiPrepFunctions.ps1

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile
Write-Log -Message $script -logFile $logFile
$adifiles = Get-ChildItem -Recurse $inputpath  -Filter *.xml

Write-host file coount $adifiles.count
if (!(Test-Path $outputpath))
    {new-item -Type Directory $outputpath}

foreach ($adifile in $adifiles) {
    copy-item $adifile $outputpath
}

$adifiles = Get-ChildItem -Recurse $outputpath -filter *.xml
foreach ($adifile in $adifiles) {
        mkdir ($adifile.directoryname + "/" + $adifile.basename).ToString()
        Move-Item $adifile.fullname ($adifile.directoryname + "/" + $adifile.basename).ToString()
        Get-ChildItem ($adifile.directoryname + "/" + $adifile.basename).tostring()
 }


