<#
.SYNOPSIS
  Script to install langauge pack and change MUI langauge

.DESCRIPTION
    Script to install langauge package and set default language

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -file Invoke-ChangeDefaultLanguage.ps1 

.NOTES
    Credit: #Original script from https://msendpointmgr.com/2024/06/09/managing-windows-11-languages-and-region-settings/
    Developed by:   Harris Bowman
    Version:        5.7
    Author:         Sandy Zeng
    Built upon by:  Harris Bowman
    Creation Date:  2025-10-09
    Updated:        2025-12-04
#>

##================================================
## MARK: Variables
##================================================

# The language we want as new default. Language tag can be found here: https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/available-language-packs-for-windows?view=windows-11#language-packs
$LPlanguage = "en-GB"

# As In some countries the input locale might differ from the installed language pack language, we use a separate input local variable.
# A list of input locales can be found here: https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs?view=windows-11#input-locales
$InputlocaleRegion = "en-GB"

# Geographical ID we want to set. GeoID can be found here: https://learn.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations
$geoId = "242"

#Time zone ID to set for the system. A full list of Time Zone IDs can be obtained by running the following command: Get-TimeZone -ListAvailable
$TimeZone = "GMT Standard Time"

# Determine log file name using set language code
$LogFileName = "Invoke-ChangeDefaultLanguage-$LPlanguage.log"

# Registry key name to track if a restart is pending    
$smallTimeZone = $TimeZone.Replace(" ", "").Replace("Standard Time", "ST")
$rkeyName = "LangChangeRestartPending-$LPlanguage-$InputlocaleRegion-$geoId-$SmallTimeZone"

##================================================
## MARK: Functions
##================================================

function Write-LogEntry {
    param (
        [parameter(Mandatory = $true, HelpMessage = "Value added to the log file.")]
        [ValidateNotNullOrEmpty()]
        [string]$Value,
        [parameter(Mandatory = $true, HelpMessage = "Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("1", "2", "3")]
        [string]$Severity
        )
        
    Write-Host $Value -ForegroundColor Cyan

    $LogFilePath = Join-Path -Path $env:windir -ChildPath $("Logs\Software\$LogFileName")
    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), " ", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
    $Date = (Get-Date -Format "MM-dd-yyyy")
    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""$($LogFileName)"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"

    try {
        Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
        if ($Severity -eq 1) {
            Write-Verbose -Message $Value
        }
        elseif ($Severity -eq 3) {
            Write-Warning -Message $Value
        }
    }
    catch [System.Exception] {
        Write-Warning -Message "Unable to append log entry to $LogFileName file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    }
}
Write-LogEntry -Value "-=-=-=- Change Default Language Script Starting -=-=-=" -Severity 1

function RegistryPathCreate {
    if (-not (Test-Path "HKLM:\SOFTWARE\LanguageChange")) {
        New-Item -Path "HKLM:\SOFTWARE\LanguageChange" -Force
        Write-LogEntry -Value "Creating registry path" -Severity 1
    }
}

##================================================
## MARK: Pre-Reqs
##================================================

#This registry key can be tattood by the GPO/Intune setting "Restricts the UI language Windows uses for all logged users" https://gpsearch.azurewebsites.net/#313
#Therefore it can interefere with the script as if it's set, the Set-SystemPreferredUILanguage command doesn't work.
Write-LogEntry -Value "Checking for tattood HKLM:\Software\Policies\Microsoft\MUI\Settings 'PreferredUILanguages' registry key." -Severity 1
if (Test-Path "HKLM:\Software\Policies\Microsoft\MUI\Settings") {
    $value = Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\MUI\Settings" -Name "PreferredUILanguages" -ErrorAction SilentlyContinue
    if ($null -ne $value) {
        Write-LogEntry -Value "Reg key HKLM:\Software\Policies\Microsoft\MUI\Settings 'PreferredUILanguages' exists. Deleting..." -Severity 1
        try {
            Remove-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\MUI\Settings" -Name "PreferredUILanguages"
            Write-LogEntry -Value "Reg key HKLM:\Software\Policies\Microsoft\MUI\Settings 'PreferredUILanguages' deleted." -Severity 1
        } catch {
            Write-LogEntry -Value "Error deleting Reg key HKLM:\Software\Policies\Microsoft\MUI\Settings 'PreferredUILanguages': $($_.Exception.Message)" -Severity 3
        }
    }
} else {
    Write-LogEntry -Value "Registry key 'HKLM:\Software\Policies\Microsoft\MUI\Settings' does not exist." -Severity 1
}

##================================================
## MARK: Detection
##================================================

Write-LogEntry -Value "Checking current system language and region values:" -Severity 1

if ((Get-SystemPreferredUILanguage) -eq $LPlanguage) {
    Write-LogEntry -Value "Get-SystemPreferredUILanguage is $LPlanguage." -Severity 1
    if ((Get-SystemLanguage) -eq $LPlanguage) {
        Write-LogEntry -Value "Get-SystemLanguage is $LPlanguage." -Severity 1
        if ((Get-Culture).Name -eq $InputlocaleRegion) {
            Write-LogEntry -Value "Get-Culture is $InputlocaleRegion." -Severity 1
            if ((Get-WinHomeLocation).GeoId -eq $geoId) {
                Write-LogEntry -Value "Get-WinHomeLocation is $geoId." -Severity 1
                if ((Get-InstalledLanguage).Language -eq $LPlanguage) {
                    if ((Get-TimeZone).Id -eq $TimeZone) {
                        RegistryPathCreate         
                        Set-ItemProperty -Path "HKLM:\SOFTWARE\LanguageChange" -Name $rkeyName -Type 'DWord' -Value 0
                        Write-LogEntry -Value "Set LangChangeRestartPending to 0" -Severity 1
                        Write-LogEntry -Value "All desired values set. Exiting with code 0." -Severity 1
                        Write-LogEntry -Value "-=-=-=- Change Default Language Script Ending -=-=-=" -Severity 1
                        Exit 0
                    } else {Write-LogEntry -Value "Get-TimeZone is not $TimeZone. Running Script" -Severity 2}
                } else {Write-LogEntry -Value "Get-InstalledLanguage is not $LPlanguage. Running Script" -Severity 2}
            } else {Write-LogEntry -Value "Get-WinHomeLocation is not $geoId. Running Script" -Severity 2}
        } else {Write-LogEntry -Value "Get-Culture is not $InputlocaleRegion. Running Script" -Severity 2}
    } else {Write-LogEntry -Value "Get-SystemLanguage is not $LPlanguage. Running Script" -Severity 2}
} else {Write-LogEntry -Value "Get-SystemPreferredUILanguage is not $LPlanguage. Running Script" -Severity 2}

Write-LogEntry -Value "Checking if a restart is pending:" -Severity 1

$restartPending = (Get-ItemProperty -Path "HKLM:\SOFTWARE\LanguageChange" -Name $rkeyName -ErrorAction SilentlyContinue).$rkeyName
if ($restartPending -eq 1) {
    Write-LogEntry -Value "Device requires a restart. Exiting with code 0." -Severity 1
    Write-LogEntry -Value "-=-=-=- Change Default Language Script Ending -=-=-=" -Severity 1
    Exit 0
}

##================================================
## MARK: Script
##================================================

#Install language pack and change the language of the OS on different places
#Install an additional language pack including FODs. With CopyToSettings (optional), this will change language for non-Unicode program. 
Write-LogEntry -Value "Installing language $LPlanguage ..." -Severity 1
try {
    Install-Language -Language $LPlanguage -CopyToSettings -ErrorAction Stop
    Write-LogEntry -Value "$LPlanguage is installed" -Severity 1
}
catch [System.Exception] {
    Write-LogEntry -Value "$LPlanguage install failed with error: $($_.Exception.Message)" -Severity 3
    exit 1
}

# Configure new language defaults under current user (system) after which it can be copied to system
Write-LogEntry -Value "Setting Win UI Language Override for regional changes $InputlocaleRegion ..." -Severity 1
try {
    Set-WinUILanguageOverride -Language $InputlocaleRegion -ErrorAction Stop
    Write-LogEntry -Value "Win UI Language Override for regional changes $InputlocaleRegion changed with no error. Restart pending." -Severity 1
}
catch [System.Exception] {
    Write-LogEntry -Value "Win UI Language Override for regional changes $InputlocaleRegion failed with error: $($_.Exception.Message)" -Severity 3
    exit 1
}

Write-LogEntry -Value "Set-WinSystemLocale to $LPlanguage running..." -Severity 1
try {
    Set-WinSystemLocale -SystemLocale $LPlanguage -ErrorAction Stop
    Write-LogEntry -Value "Set-WinSystemLocale to $LPlanguage sucsessfull." -Severity 1
}
catch [System.Exception] {
    Write-LogEntry -Value "Set-WinSystemLocale to $LPlanguage failed with error: $($_.Exception.Message)" -Severity 3
    exit 1
}

Write-LogEntry -Value "Set-SystemPreferredUILanguage to $LPlanguage running..." -Severity 1
try {
    Set-SystemPreferredUILanguage $LPlanguage -ErrorAction Stop
    Write-LogEntry -Value "Set-SystemPreferredUILanguage to $LPlanguage sucsessfull." -Severity 1
}
catch [System.Exception] {
    Write-LogEntry -Value "Set-SystemPreferredUILanguage to $LPlanguage failed with error: $($_.Exception.Message)" -Severity 3
    exit 1
}

# adding the input locale language to the preferred language list, and make it as the first of the list. 
Write-LogEntry -Value "Setting Win User Language List to $InputlocaleRegion" -Severity 1
try {
    $UserLanguageList = New-WinUserLanguageList -Language $InputlocaleRegion -ErrorAction Stop
    Set-WinUserLanguageList -LanguageList $UserLanguageList -Force -ErrorAction Stop
    Write-LogEntry -Value "Win User Language List is changed with no error. Restart pending." -Severity 1
}
catch [System.Exception] {
    Write-LogEntry -Value "Win User Language List failed with error: $($_.Exception.Message)" -Severity 3
    exit 1
}

# Set Win Home Location, sets the home location setting for the current user. This is for Region location 
Write-LogEntry -Value "Setting Region location $geoId ..." -Severity 1
try {
    Set-WinHomeLocation -GeoId $geoId -ErrorAction Stop
    Write-LogEntry -Value "Set Region to $geoId sucsessfully. Checking..." -Severity 1
    if ((Get-WinHomeLocation).GeoId -eq $geoId) {
        Write-LogEntry -Value "Region is $geoId." -Severity 1
    } else { 
        Write-LogEntry -Value "Set Region sucseeded without error but not set system wide. Unknown Error." -Severity 3
    }
}
catch [System.Exception] {
    Write-LogEntry -Value "Set Region failed with error: $($_.Exception.Message)" -Severity 3
    exit 1
}

# Set Culture, sets the user culture for the current user account. This is for Region format
Write-LogEntry -Value "Setting Culture to $InputlocaleRegion ..." -Severity 1
try {
    Set-Culture -CultureInfo $InputlocaleRegion -ErrorAction Stop
    Write-LogEntry -Value "Set Culture to $InputlocaleRegion changed with no error." -Severity 1
}
catch [System.Exception] {
    Write-LogEntry -Value "Set Culture failed with error: $($_.Exception.Message)" -Severity 3
    exit 1
}

# Copy User International Settings from current user to System, including Welcome screen and new user
Write-LogEntry -Value "Coping User International Settings from current user to System..." -Severity 1
try {
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $True -NewUser $True -ErrorAction Stop
    Write-LogEntry -Value "Copy User International Settings from current user to System sucsessfully." -Severity 1
}
catch [System.Exception] {
    Write-LogEntry -Value "Copy User International Settings from current user to System failed with error: $($_.Exception.Message)" -Severity 3
    exit 1
}

# Will only run the following two commands once in theory - These are less importants as they are mostly fixed on all machines.
Write-LogEntry -Value "Setting Time Zone." -Severity 1
try {
    Set-TimeZone -Id $TimeZone -ErrorAction Stop
    Write-LogEntry -Value "Set Time Zone to $TimeZone sucsessfully." -Severity 1
}
catch [System.Exception] {
    Write-LogEntry -Value "Set Time Zone to $TimeZone failed with error: $($_.Exception.Message)" -Severity 3
    exit 1
}

RegistryPathCreate
Set-ItemProperty -Path "HKLM:\SOFTWARE\LanguageChange" -Name $rkeyName -Type 'DWord' -Value 1
Write-LogEntry -Value "Set LangChangeRestartPending to 1" -Severity 1

Write-LogEntry -Value "-=-=-=- Change Default Language Script Ending -=-=-=" -Severity 1

#Yeh, I'm exiting with a Soft Restart code that won't do anything. After the scheduled task is ran it is up to the user to sign out and back in again or restart.
#If in future someone figures out how to get a Scheduled Task to trigger a Restart dialouge in Windows like App Installs can do then let me know.
Exit 3010