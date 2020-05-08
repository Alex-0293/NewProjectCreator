<#
    .SYNOPSIS 
        .AUTOR
        .DATE
        .VER
    .DESCRIPTION
    .PARAMETER
    .EXAMPLE
#>
Clear-Host
$Global:ScriptName = $MyInvocation.MyCommand.Name
$InitScript        = "C:\DATA\Projects\GlobalSettings\SCRIPTS\Init.ps1"
if (. "$InitScript" -MyScriptRoot (Split-Path $PSCommandPath -Parent) -force) { exit 1 }

# Error trap
trap {
    if ($Global:Logger) {
       Get-ErrorReporting $_
        . "$GlobalSettings\$SCRIPTSFolder\Finish.ps1" 
    }
    Else {
        Write-Host "There is error before logging initialized." -ForegroundColor Red
    }   
    exit 1
}
################################# Script start here #################################

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

if( -not $ProjectType ) {
    while ( ($ProjectType.ToUpper() -ne "P") -and ($ProjectType.ToUpper() -ne "S") ) {
        $ProjectType    = Read-host -Prompt "Select project type, Project or Service [P/S]" 
        switch ($ProjectType.ToUpper()) {
            "P" { $Destination= $Projects }
            "S" { $Destination = $ProjectServices }
            Default {}
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

[array] $Content = Get-Content -path $NewScriptFilePath
[array] $NewContent = @()

foreach ($Line in $Content){
    $NewLine = Set-Params $ScriptParams $Line
    $NewContent += $NewLine
}

if ($NewContent) {
    $NewContent | Out-File -FilePath $NewScriptFilePath -Encoding utf8BOM
}
Add-ToLog -Message "Renaming main script [$NewScriptFilePath] to [$Destination\$NewProjectName\$SCRIPTSFolder\$NewProjectName.ps1]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)
Rename-Item -Path $NewScriptFilePath -NewName "$Destination\$NewProjectName\$SCRIPTSFolder\$NewProjectName.ps1"

if ($GitInit){
    Add-ToLog -Message "Initializing git in folder [$Destination\$NewProjectName]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)
    Set-Location "$Destination\$NewProjectName\"
    & git.exe init
    $Answer = Read-Host -Prompt "Add remote origin? (y/N)"
    if ($Answer.ToUpper() -eq "Y"){
        $Origin = Read-Host -Prompt "Enter origin URL"
        Set-Location "$Destination\$NewProjectName\"
        Add-ToLog -Message "Adding git remote origin [$Origin]." -logFilePath $ScriptLogFilePath -Display -status "info"  -Level ($ParentLevel + 1)
        & git.exe " remote add origin $Origin"
    }
}

################################# Script end here ###################################
. "$GlobalSettings\$SCRIPTSFolder\Finish.ps1"