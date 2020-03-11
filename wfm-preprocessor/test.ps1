
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
#Set-Location $ScriptDir

# load helper functions
. ./PreprocessorFunctions.ps1

$catcherpath = "/assets/Armstrong/arm2/"

$logFile = "./removeingestedassetsfromcatcher-" + (Get-Date -Format yyyy-MM-dd) + ".log"
$delayhours = 48

$catcher = Get-ChildItem $catcherpath -recurse | Where-Object { $_.PSIsContainer } 
foreach ($subdir in $catcher) 
{
    write-host checking $subdir
     if (((Get-ChildItem $subdir -Filter *.xml).count) -eq 0)
        {
            if (((Get-Date) - $subdir.LastWriteTime).TotalHours -lt $delayhours)
            {
                write-host "Not removing incomplete folder $subdir, not older than $delayhours, "
                Write-Log -Message "Not removing incomplete folder $subdir, not older than $delayhours" -logFile $logFile
            } else {
                write-host "Removing incomplete folder $subdir"
                Write-Log -Message "Removing incomplete folder $subdir" -logFile $logFile
                #Delete the folder  
                #Remove-Item $subdir -Force -Recurse
            }
        }
} 