
function Skip-CurrentTransfers {
    <#
        .Synopsis
          The short function description.
        .Description
            The long function description
        .Example
            C:\PS>Function-Name -param "Param Value"
            
            This example does something
        .Example
            C:\PS>
            
            You can have multiple examples
        .Notes
            Name: Function-Name
            Author: Author Name
            Last Edit: Date
            Keywords: Any keywords
        .Inputs
            $folder - folder to check for files with recent timestamps (currently copying files)
        .Outputs
            [bool]$recentFileWrite
        #Requires -Version 2.0
        #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Enter folder to check for recently modified files")]
        [System.IO.DirectoryInfo]$folder
    )
    process {
        try {
            $files = Get-ChildItem $folder -Exclude *.xml, *.bak, *.jpg
            [bool]$recentFileWrite = $false
            $delay = -1
            foreach ($file in $files) {
                if ($file.LastWriteTime -ge (Get-Date).AddMinutes($delay)) {
                    if ($file.Name -ne $adifile.Name) {
                        #flag that file timestamps are too new to mark folder with .wfmready 
                        $recentFileWrite = $true
                        $timediff = ((Get-Date) - $file.LastWriteTime).TotalMinutes | ForEach-Object { $_.ToString("#.#") }
                        Write-Log -Message "Skip-CurrentTransfer - $file last write minutes ago: $timediff " -logFile $logFile
                        Write-Host ""
                    }
                }
            }

            if ($recentFileWrite -eq $false) {
                Write-Log -Message "Folder doesn't appear to be currently copying files" -logFile $logFile
            }
            return $recentFileWrite
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function


function Add-WfmReadyFile {
    <#
        .Synopsis
          The short function description.
        .Description
            The long function description
        .Example
            C:\PS>Function-Name -param "Param Value"
            
            This example does something
        .Example
            C:\PS>
            
            You can have multiple examples
        .Notes
            Name: Function-Name
            Author: Author Name
            Last Edit: Date
            Keywords: Any keywords
        .Inputs
            None
        .Outputs
            None
        #Requires -Version 2.0
        #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Enter folder to mark with .wfmready file")]
        [System.IO.DirectoryInfo]$folder
    )
    process {
        try {
            $files = Get-ChildItem $folder.FullName -exclude *.xml, *.bak, *.jpg
            $adifile = Get-ChildItem $folder.FullName -Filter *.xml
            $delay = -1
            $recentFileWrite = $false
            foreach ($file in $files) {
                Write-Host $File.Name $file.LastWriteTime
                #Write-Host File is   ((Get-Date)-($file.LastWriteTime)) minutes old
                if ($file.LastWriteTime -ge (Get-Date).AddMinutes($delay)) {
                    if ($file.Name -ne $adifile.Name) {
                        #flag that file timestamps are too new to mark folder with .wfmready 
                        $recentFileWrite = $true
                        $timediff = ((Get-Date) - $file.LastWriteTime).TotalMinutes | ForEach-Object { $_.ToString("#.#") }
                        Write-Log -Message "$file last write minutes ago: $timediff " -logFile $logFile
                        Write-Host ""
                    }
                }
            }

            if ($recentFileWrite -eq $false) {
                Write-Log -Message "no new files, tagging folder with .wfmready file" -logFile $logFile
                New-Item ($adifile.DirectoryName.ToString() + "/" + $adifile.BaseName + ".wfmready") -Type file
            }
        }
        catch {
            Write-Host $PSItem.InvocationInfo
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Log -Message $_.Exception.Message -Severity "Error" -logFile $logFile
        }
    }
} #End function

function Write-Log {
    <#
    .Synopsis
    The short function description.
    .Description
        The long function description
    .Example
        C:\PS>Function-Name -param "Param Value"
        
        This example does something
    .Example
        C:\PS>
        
        You can have multiple examples
    .Notes
        Name: Function-Name
        Author: Author Name
        Last Edit: Date
        Keywords: Any keywords
    .Inputs
        None
    .Outputs
        None
    #Requires -Version 2.0
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information',

        [Parameter(Mandatory = $true)]
        [string]$logFile = "$env:Temp\LogFile.csv"
    )

    [pscustomobject]@{
        Time     = (Get-Date -f g)
        Severity = $Severity
        Message  = $Message
    } | Export-Csv -Path $logFile -Append -NoTypeInformation
}


$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$logFile = "./add-wfmready_" + (Get-Date -Format yyyy-MM-dd) + ".log"

# load helper functions
. ./PreprocessorFunctions.ps1

# set required variables
$catcher = "/path/to/catcher"

Write-Log -Message "|--------------Starting script--------------------|" -logFile $logFile

# process ADI files
$adifiles = Get-ChildItem -Recurse $catcher -Filter *.xml
foreach ($adifile in $adifiles) {
    if ((Get-ChildItem $adifile.DirectoryName -Name *.wfmready).count -gt 0) {
        # skip folders already containing a .wfmready file
        Write-Host $adifile.DirectoryName already processed
    }
    else {
        $skip = (Skip-CurrentTransfers -folder $adifile.DirectoryName)
        if (!($skip[$skip.count - 1])) {
            Write-Log -Message "processing $adifile" -logFile $logFile
            Add-WfmReadyFile -folder $adifile.DirectoryName
            Write-Log -Message "--- finished processing $adifile" -logFile $logFile
        }
    }
}