# Rename this file to Settings.ps1
######################### value replacement #####################

[string] $Global:InitScriptPath      = ""          
[string] $Global:FinishScript        = ""         

[string] $Global:ScriptAuthor = ""         
[string] $Global:ScriptVer    = ""         
[string] $Global:ScriptLang   = ""         

[string] $Global:NewProjectName        = ""         
[string] $Global:NewProjectDescription = ""         
# https://help.github.com/en/github/creating-cloning-and-archiving-repositories/licensing-a-repository#searching-github-by-license-type
[string] $Global:NewProjectGPL         = ""         
[string] $Global:ProjectType           = ""          # Select project type [Project/Service/Other]

[bool]   $Global:GitHubPrivateScope    = ""          
[bool]   $Global:AddRemoteOrigin       = ""          
[bool]   $Global:InitMermaidDiagram    = ""          
######################### no replacement ########################

[string] $Global:TemplateScriptFileName = "ScriptTemplate.ps1" 
[string] $Global:Component              = "Module: AlexkUtils                   ( https://github.com/Alex-0293/PS-Modules ) `n        Init, finish scripts: GlobalSettings ( https://github.com/Alex-0293/GlobalSettings )"
[array]  $Global:FolderToRemove         = @("ACL",".git")

[string] $Global:MermaidDiagram         = @'
#################################  Mermaid diagram  #################################
<#
```mermaid

```
#>
'@

$Global:ScriptParams = [PSCustomObject]@{
    Author         = $Global:ScriptAuthor 
    Ver            = $Global:ScriptVer
    Lang           = $Global:ScriptLang
    Component      = ""#$Global:Component 
    Date           = (Get-Date -Format $GlobalDateFormat)
    InitScriptPath = $InitScriptPath
    FinishScript   = $FinishScript
    MermaidDiagram = $Global:MermaidDiagram 
}

[bool]   $Global:GitInit                         = $true

[bool]  $Global:LocalSettingsSuccessfullyLoaded  = $true
# Error trap
    trap {
        $Global:LocalSettingsSuccessfullyLoaded = $False
        exit 1
    }
