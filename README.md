# LanguageChange
Intune Deployable application which can install and set Windows Languages, Input methods, Location and Time Zone. 

# Deployment
1) Download all the files in this repository
2) Open <ins>Files/Invoke-ChangeDefaultLanguage.ps1</ins>
3) Go to the Variables section and edit the variables to whatever Language, Locale, Location, and Time Zone desired.
4) Save <ins>Files/Invoke-ChangeDefaultLanguage.ps1</ins>
5) Package the application up using the Intune Win32 Prep Tool https://learn.microsoft.com/en-us/intune/intune-service/apps/apps-win32-prepare
The installation file is <ins>Invoke-AppDeployToolkit.exe</ins> - All the files need to be included in the folder, no catalouge files are needed.
6) Upload the .INTUNEWIM generated in step 5 to Intune with:
- The install command being: `Invoke-AppDeployToolkit.exe -DeploymentType Install -DeployMode Silent`
- The uninstall command being `Invoke-AppDeployToolkit.exe -DeploymentType Uninstall -DeployMode Silent`
- The detection method being the script <ins>Detect-ChangeDefaultLangTaskSch.ps1</ins>
   
# Disclaimer
This repo uses files from PSAppDeployToolkit: https://github.com/PSAppDeployToolkit/PSAppDeployToolkit which uses the [LGPL-3.0 license](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit?tab=LGPL-3.0-1-ov-file#readme).
