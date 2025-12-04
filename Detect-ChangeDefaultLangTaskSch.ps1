
function GetSchTask {
    $taskName = "Change System Language"
    $taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName }
    if($taskExists) {
        Write-Host "Task Exists. " -ForegroundColor Green
        Return $true
    } else {
        Write-Host "Task does not exist. " -ForegroundColor Red
        Return $false
    }
}

function ScriptExists {
    try {
        if (Test-Path -Path "C:\Program Files\LanguageChange\Invoke-ChangeDefaultLanguage.ps1") {
            # If the script version is changed on line 14 the below regex will need changing to the new version numbers.
            if (Select-String -Path "C:\Program Files\LanguageChange\Invoke-ChangeDefaultLanguage.ps1" -Pattern "^\s*Version:\s+5\.7$") {
                Write-Host "Correct script version. " -ForegroundColor Green
                Return $true
            } else {
                Write-Host "Incorrect script version. " -ForegroundColor Red
                Return $false
            }
        } else {
            Write-Host "Script does not exist. " -ForegroundColor Red
            Return $false
        }
    } catch {
        Return $false
    } 
}

if (GetSchTask) {
    if (ScriptExists) {
        Exit 0
    } else {
        Exit 1
    }
} else{
    Exit 1
}