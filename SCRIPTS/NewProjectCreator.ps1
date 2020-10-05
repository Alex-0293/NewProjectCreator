<#
    .SYNOPSIS 
        AUTHOR
        DATE
        VER
    .DESCRIPTION
    
    .EXAMPLE
#>
Param (
    [Parameter( Mandatory = $false, Position = 0, HelpMessage = "Initialize global settings." )]
    [bool] $InitGlobal = $true,
    [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Initialize local settings." )]
    [bool] $InitLocal = $true   
)

$Global:ScriptInvocation = $MyInvocation
if ($env:AlexKFrameworkInitScript){. "$env:AlexKFrameworkInitScript" -MyScriptRoot (Split-Path $PSCommandPath -Parent) -InitGlobal $InitGlobal -InitLocal $InitLocal} Else {Write-host "Environmental variable [AlexKFrameworkInitScript] does not exist!" -ForegroundColor Red; exit 1}
if ($LastExitCode) { exit 1 }
# Error trap
trap {
    if (get-module -FullyQualifiedName AlexkUtils) {
        Get-ErrorReporting $_        
        . "$($Global:gsGlobalSettingsPath)\$($Global:gsSCRIPTSFolder)\Finish.ps1" 
    }
    Else {
        Write-Host "[$($MyInvocation.MyCommand.path)] There is error before logging initialized. Error: $_" -ForegroundColor Red
    }  
    $Global:gsGlobalSettingsSuccessfullyLoaded = $false
    exit 1
}
################################# Script start here #################################
$Res = import-module PowerShellForGitHub -PassThru
if (-not $res) {
    Add-ToLog -Message "Module [PowerShellForGitHub] import unsuccessful!" -Display -Status "Error" -logFilePath $Global:gsScriptLogFilePath
    exit 1
}
Else {
    Set-GitHubConfiguration -DisableTelemetry
}
Function Set-Params ($ScriptParams,[string] $NewLine){
    foreach ($Key in ($ScriptParams | Get-Member -MemberType NoteProperty).Name) {
        $ReplaceString = "%$($Key)%"
        $Value         = $ScriptParams.$Key
        $NewLine = $NewLine.Replace($ReplaceString, $Value) 
    }
    Return $NewLine
}

$Global:gsParentLevel ++

if ( -not $NewProjectName) {
    $NewProjectName = Read-Host -Prompt "Input new project name"
}
Add-ToLog -Message "Set project name to [$NewProjectName]." -logFilePath $Global:gsScriptLogFilePath -Display -status "info"  
if ( -not $NewProjectDescription) {
    $NewProjectDescription = Read-Host -Prompt "Input new project description"
}
Add-ToLog -Message "Set project description to [$NewProjectDescription]." -logFilePath $Global:gsScriptLogFilePath -Display -status "info"  

if ( -not $ProjectType ) {
    while ( ($ProjectType.ToUpper() -ne "Project") -and ($ProjectType.ToUpper() -ne "Service" ) -and ($ProjectType.ToUpper() -ne "Other")) {
        $ProjectType = Read-Host -Prompt "Select project type, Project or Service or Other [Project/Service/Other]" 
        switch ($ProjectType.ToUpper()) {
            "Project" { $Destination = $Global:gsProjectsFolderPath }
            "Service" { $Destination = $Global:gsProjectServicesFolderPath }
            "Other"   { $Destination = $Global:gsOtherProjectsFolderPath }
            Default { }
        }
    }
}
Else {
    switch ($ProjectType.ToUpper()) {
        "Project" { $Destination = $Global:gsProjectsFolderPath }
        "Service" { $Destination = $Global:gsProjectServicesFolderPath }
        "Other"   { $Destination = $Global:gsOtherProjectsFolderPath }
        Default { }
    }    
}

#Remove-Item "$Destination\$NewProjectName" -Force -Recurse | Out-Null

if (Test-path "$Destination\$NewProjectName") {
    Add-ToLog -Message "Project folder [$Destination\$NewProjectName] is already exist!" -logFilePath $Global:gsScriptLogFilePath -Display -status "error"
    throw "Project folder [$Destination\$NewProjectName] is already exist!"
}
Else {
    Add-ToLog -Message "Creating project folder [$Destination\$NewProjectName]." -logFilePath $Global:gsScriptLogFilePath -Display -status "info" 
    New-Item "$Destination\$NewProjectName" -ItemType Directory | Out-Null
    Add-ToLog -Message "Copying template data from [$($Global:gsTemplateProjectPath)\*] to [$Destination\$NewProjectName] exclude [$($FolderToRemove -join ", ")]." -logFilePath $Global:gsScriptLogFilePath -Display -status "info" 
    Copy-Item -Path (Get-Item -Path "$($Global:gsTemplateProjectPath)\*" -Exclude $FolderToRemove).FullName -Destination "$Destination\$NewProjectName" -Recurse | Out-Null
}

$NewScriptFilePath = "$Destination\$NewProjectName\$($Global:gsSCRIPTSFolder)\$($Global:TemplateScriptFileName)"
$ScriptParams | Add-Member -MemberType NoteProperty -Name "Description" -Value $NewProjectDescription
$ScriptParams | Add-Member -MemberType NoteProperty -Name "Example"     -Value "$NewProjectName.ps1"
Remove-Item "$Destination\$NewProjectName\$($Global:gsSCRIPTSFolder)\ScriptToCopy.ps1"

Add-ToLog -Message "Renaming main script [$NewScriptFilePath] to [$Destination\$NewProjectName\$($Global:gsSCRIPTSFolder)\$NewProjectName.ps1]." -logFilePath $Global:gsScriptLogFilePath -Display -status "info" 
$RenamedScript = "$Destination\$NewProjectName\$($Global:gsSCRIPTSFolder)\$NewProjectName.ps1"
Rename-Item -Path $NewScriptFilePath -NewName $RenamedScript 

if ($GitInit){
    Add-ToLog -Message "Initializing git in folder [$Destination\$NewProjectName]." -logFilePath $Global:gsScriptLogFilePath -Display -status "info"  
    Set-Location "$Destination\$NewProjectName\"    
    if (-not $AddRemoteOrigin) {
        $Answer = Read-Host -Prompt "Add remote origin? (y/N)"
    }
    Else {
        $Answer = "y"
    }
    $ProjectURL = ""
    
    if ($Answer.ToUpper() -eq "Y") {        
        if ($Global:GitHubPrivateScope) {
            $Res = New-GitHubRepository -RepositoryName $NewProjectName -Description $NewProjectDescription -NoWiki -NoIssues -AutoInit -LicenseTemplate $NewProjectGPL -Private
            $ProjectURL = $Res.clone_url
        }
        Else {
            $Res = New-GitHubRepository -RepositoryName $NewProjectName -Description $NewProjectDescription -NoWiki -NoIssues -AutoInit -LicenseTemplate $NewProjectGPL
            $ProjectURL = $Res.clone_url
        }
        Add-ToLog -Message "Set project URL to [$ProjectURL]." -logFilePath $Global:gsScriptLogFilePath -Display -status "info" 
        $NewProjectName = (Split-Path -path $ProjectURL -Leaf).Split(".")[0]
    }    
}

$ScriptParams | Add-Member -MemberType NoteProperty -Name "ProjectURL"  -Value "$ProjectURL"

[array] $Content = Get-Content -path $RenamedScript
[array] $NewContent = @()

if ( -not $Global:InitMermaidDiagram){
    $NewContent.Replace($Global:MermaidDiagram, "")
}

foreach ($Line in $Content) {
    $NewLine = Set-Params $ScriptParams $Line
    $NewContent += $NewLine
}



if ($NewContent) {
    $NewContent | Out-File -FilePath $RenamedScript -Encoding utf8BOM
}

if ($ProjectURL){
    Set-Location "$Destination\$NewProjectName\"
    Add-ToLog -Message "Adding git remote origin [$ProjectURL]." -logFilePath $Global:gsScriptLogFilePath -Display -status "info" 
    & git.exe init
    & git.exe add .
    & git.exe commit -m "Creation commit."
    & git.exe remote add origin $ProjectURL
    & git.exe pull origin master --allow-unrelated-histories
    & git.exe push -u origin master
}
$Global:gsParentLevel --
################################# Script end here ###################################
. "$($Global:gsGlobalSettingsPath)\$($Global:gsSCRIPTSFolder)\Finish.ps1"
