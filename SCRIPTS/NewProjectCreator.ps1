<#
    .SYNOPSIS 
        .AUTHOR
        .DATE
        .VER
    .DESCRIPTION
    .PARAMETER
    .EXAMPLE
#>
Param (
    [Parameter( Mandatory = $false, Position = 0, HelpMessage = "Initialize global settings." )]
    [bool] $InitGlobal = $true,
    [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Initialize local settings." )]
    [bool] $InitLocal = $true   
)

$Global:ScriptInvocation = $MyInvocation
$InitScript        = "C:\DATA\Projects\GlobalSettings\SCRIPTS\Init.ps1"
if (. "$InitScript" -MyScriptRoot (Split-Path $PSCommandPath -Parent) -InitGlobal $InitGlobal -InitLocal $InitLocal) { exit 1 }

# Error trap
trap {
    if (get-module -FullyQualifiedName AlexkUtils) {
        Get-ErrorReporting $_        
        . "$GlobalSettings\$SCRIPTSFolder\Finish.ps1" 
    }
    Else {
        Write-Host "[$($MyInvocation.MyCommand.path)] There is error before logging initialized. Error: $_" -ForegroundColor Red
    }  
    $Global:GlobalSettingsSuccessfullyLoaded = $false
    exit 1
}
################################# Script start here #################################
$Res = import-module PowerShellForGitHub -PassThru
if (-not $res) {
    Add-ToLog -Message "Module [PowerShellForGitHub] import unsuccessful!" -Display -Status "Error" -logFilePath $ScriptLogFilePath
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

if ( -not $NewProjectName) {
    $NewProjectName = Read-Host -Prompt "Input new project name"
}
Add-ToLog -Message "Set project name to [$NewProjectName]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)

if ( -not $NewProjectDescription) {
    $NewProjectDescription = Read-Host -Prompt "Input new project description"
}
Add-ToLog -Message "Set project description to [$NewProjectDescription]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)

if ( -not $ProjectType ) {
    while ( ($ProjectType.ToUpper() -ne "P") -and ($ProjectType.ToUpper() -ne "S") ) {
        $ProjectType = Read-Host -Prompt "Select project type, Project or Service [P/S]" 
        switch ($ProjectType.ToUpper()) {
            "P" { $Destination = $Projects }
            "S" { $Destination = $ProjectServices }
            Default { }
        }
    }
}
Else {
    switch ($ProjectType.ToUpper()) {
        "P" { $Destination = $Projects }
        "S" { $Destination = $ProjectServices }
        Default { }
    }    
}

#Remove-Item "$Destination\$NewProjectName" -Force -Recurse | Out-Null

if (Test-path "$Destination\$NewProjectName") {
    Add-ToLog -Message "Project folder [$Destination\$NewProjectName] is already exist!" -logFilePath $ScriptLogFilePath -Display -status "error"  -Level ($ParentLevel + 1)
    throw "Project folder [$Destination\$NewProjectName] is already exist!"
}
Else {
    Add-ToLog -Message "Creating project folder [$Destination\$NewProjectName]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)
    New-Item "$Destination\$NewProjectName" -ItemType Directory | Out-Null
    Add-ToLog -Message "Copying template data from [$TemplateProjectPath\*] to [$Destination\$NewProjectName] exclude [$($FolderToRemove -join ", ")]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)
    Copy-Item -Path (Get-Item -Path "$TemplateProjectPath\*" -Exclude $FolderToRemove).FullName -Destination "$Destination\$NewProjectName" -Recurse | Out-Null
}

$NewScriptFilePath = "$Destination\$NewProjectName\$SCRIPTSFolder\Script.ps1"
$ScriptParams | Add-Member -MemberType NoteProperty -Name "Description" -Value $NewProjectDescription
$ScriptParams | Add-Member -MemberType NoteProperty -Name "Example"     -Value "$NewProjectName.ps1"

Add-ToLog -Message "Renaming main script [$NewScriptFilePath] to [$Destination\$NewProjectName\$SCRIPTSFolder\$NewProjectName.ps1]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)
$RenamedScript = "$Destination\$NewProjectName\$SCRIPTSFolder\$NewProjectName.ps1"
Rename-Item -Path $NewScriptFilePath -NewName $RenamedScript 

if ($GitInit){
    Add-ToLog -Message "Initializing git in folder [$Destination\$NewProjectName]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)
    Set-Location "$Destination\$NewProjectName\"    
    $Answer = Read-Host -Prompt "Add remote origin? (y/N)"
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
        Add-ToLog -Message "Set project URL to [$ProjectURL]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)
        $NewProjectName = (Split-Path -path $ProjectURL -Leaf).Split(".")[0]
    }    
}

$ScriptParams | Add-Member -MemberType NoteProperty -Name "ProjectURL"  -Value "$ProjectURL"

[array] $Content = Get-Content -path $RenamedScript
[array] $NewContent = @()

foreach ($Line in $Content) {
    $NewLine = Set-Params $ScriptParams $Line
    $NewContent += $NewLine
}

if ($NewContent) {
    $NewContent | Out-File -FilePath $RenamedScript -Encoding utf8BOM
}

if ($ProjectURL){
    Set-Location "$Destination\$NewProjectName\"
    Add-ToLog -Message "Adding git remote origin [$ProjectURL]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)
    & git.exe init
    & git.exe add .
    & git.exe commit -m "Creation commit."
    & git.exe remote add origin $ProjectURL
    & git.exe pull origin master --allow-unrelated-histories
    & git.exe push -u origin master
}

################################# Script end here ###################################
. "$GlobalSettings\$SCRIPTSFolder\Finish.ps1"