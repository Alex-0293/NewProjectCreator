# Rename this file to Settings.ps1
######################### value replacement #####################

[string] $Global:InitScriptPath      = ""         
[string] $Global:FinishScript        = ""         
[string] $Global:ProjectServices     = ""         
[string] $Global:Projects            = ""         
[string] $Global:TemplateProjectPath = ""         

[string] $Global:ScriptAuthor        = ""         
[string] $Global:ScriptVer           = ""         
[string] $Global:ScriptLang          = ""         

[string] $Global:NewProjectName        = ""         
[string] $Global:NewProjectDescription = ""         
[string] $Global:ProjectType           = ""         

######################### no replacement ########################

[array]  $Global:FolderToRemove      = @("ACL",".git")

$Global:ScriptParams = [PSCustomObject]@{
    Author         = $Global:ScriptAuthor 
    Ver            = $Global:ScriptVer
    Lang           = $Global:ScriptLang 
    Date           = (Get-Date -Format $GlobalDateFormat)
    InitScriptPath = $InitScriptPath
    FinishScript   = $FinishScript
}

[bool]   $Global:GitInit                    = $true

[bool]  $Global:LocalSettingsSuccessfullyLoaded  = $true
# Error trap
    trap {
        $Global:LocalSettingsSuccessfullyLoaded = $False
        exit 1
    }
