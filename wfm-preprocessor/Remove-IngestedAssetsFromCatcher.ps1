
<#
    .SYNOPSIS
        This script removes the asset folders for assets that have been successfully ingested
    .DESCRIPTION
        This script deletes asset folders from the catcher that have been marked as completed with a .deleteready file
#>

function Remove-FolderAndContents {

    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Enter folder with .deleteready file")]
        [System.IO.DirectoryInfo]$folder
    )

    process {
        $child_items = ([array] (Get-ChildItem -Path $folder -Recurse -Force))
        if ($child_items) {
            $null = $child_items | Remove-Item -Force -Recurse
        }
        $null = Remove-Item $folder -Force
    }
}

$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# load helper functions
. ./PreprocessorFunctions.ps1

$logFile = "./removeingestedassetsfromcatcher-" + (Get-Date -Format yyyy-MM-dd) + ".log"
$deletemarkers = Get-ChildItem -Recurse "/assets/Armstrong/delete-test/" -Include *.deleteready 
# if null, try again with hidden attribute
if ($null -eq $deletemarkers) {
    $deletemarkers = Get-ChildItem -Recurse "/assets/Armstrong/delete-test/" -Include *.deleteready  -Attributes Hidden
}
Write-Log -Message "Completed assets found: $deletemarkers.Count" -logFile $logFile
$delayhours = 48

foreach ($marker in $deletemarkers)
{
    [int]$timediff = ((Get-Date) - $marker.LastWriteTime).TotalHours
    if ( $timediff -gt $delayhours)
    {
        $markerfolder = $marker.DirectoryName
        Write-Log -Message "removing folder: $markerfolder" -logFile $logFile
        Remove-FolderAndContents -folder $markerfolder
    }
    else
    {
        Write-Log -Message "$marker is $timediff hours old, less than minimum of $delayhours to remove, skipping folder" -logFile $logFile
    }
}