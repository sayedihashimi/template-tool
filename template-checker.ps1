Param(
  [Parameter(Mandatory=$true)]
  [string]$templatePath,
  
  [string]$templateXsdPath,

  [switch]$reportNugetPackages
)

######## Begin functions ######## 

function Get-ScriptDirectory
{
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value
	Split-Path $Invocation.MyCommand.Path
}

# taken from http://stackoverflow.com/a/16737772/105999
# note this only works for XML files which do not have an xmlns declaration
function Test-Xml {
param(
    [Parameter(ValueFromPipeline=$true)]
    $xmlFile = $null,
    $schemaFile = $null
)

BEGIN {
    $failureMessages = ""
    $script:isValid = $true
}

PROCESS {
    $script:Context = New-Object -TypeName System.Management.Automation.PSObject
    Add-Member -InputObject $Context -MemberType NoteProperty -Name Configuration -Value ""
    $ConfigurationPath = $(Join-Path -Path $PWD -ChildPath "Configuration")

    # Load xml and its schema
    $Context.Configuration = [xml](Get-Content -LiteralPath $xmlFile)
    $Context.Configuration.Schemas.Add($null, $schemaFile) | Out-Null    

    Try{
    $Context.Configuration.Validate(
        {
            $script:isValid = $false
            $failureMessages +=  ("$($_.Message)" + [System.Environment]::NewLine)            
            "ERROR: The XML file [$xmlFile] is not valid. $($_.Message)" | Write-Error
        })
    }
    Catch{
        [System.Exception]
        $script:isValid = $false
        $error
    }
}
End{ return $script:isValid }

}
function IsTemplateXmlValid(){
    Param(
        [Parameter(Mandatory=$true)]
        [string]$templatePath,
        [Parameter(Mandatory=$true)]
        [string]$templateXsdPath
    )

    if(!(Test-Path $templatePath)){
        "Template file not found at [{0}]" -f $templatePath | Write-Error
        return $false
    }
    if(!(Test-Path $templateXsdPath)){
        "Template xsd file not found at [{0}]" -f $templateXsdPath | Write-Error
        return $false
    }

    # requires the xml-helpers module be loaded
    $isValid = (Test-Xml -xmlFile $templatePath -schemaFile $templateXsdPath)
    return $isValid
}
function ValidateBaseTemplateId(){
    Param(
        [Parameter(Mandatory=$true)]
        [xml]$template
    )
    
    Begin{"ValidateBaseTemplateId starting" | Write-Verbose }

    Process{
        $baseTempErrors = @()
        $errorFound = $false
        # check that the BaseTemplateId attribute value has a corresponding BaseElement in the same file
        $baseTemplateIdsFromTemplate= ($template.TemplateDefinition.UI.Template.BaseTemplateID)

        foreach($baseTempId in $baseTemplateIdsFromTemplate){
            # check to see that there is a corresponding value for BaseTemplates.BaseTemplate.ID
            $foundBaseTempId = $template.TemplateDefinition.BaseTemplates.BaseTemplate.ID | Where-Object { [string]::Compare($_,$baseTempId,$true) -eq 0}
            "Checking BaseTemplates.BaseTemplate.ID value for UI.Template.BaseTemplateID [{0}]" -f $baseTempId | Write-Verbose
            if(!$foundBaseTempId){
                $errorFound = $true
                $msg = ("Missing BaseTemplates.BaseTemplate.ID value for UI.Template.BaseTemplateID [{0}]" -f $baseTempId)
                $baseTempErrors += $msg
                $msg | Write-Error
            }
        }   
    }
    End{
        if($errorFound){ return $baseTempErrors }
        else{ "no errors in ValidateBaseTemplateId" | Write-Host -ForegroundColor Green}
        "ValidateBaseTemplateId finished" | Write-Verbose 
    }
}
function ValidateUnitTestIdFromUI(){
    param(
        [Parameter(Mandatory=$true)]
        [xml]$template
    )

    begin{ "ValidateUnitTestIdFromUI starting" | Write-Verbose }
    
    process{
        $unitErrors = @()
        $errorsFound = $false
        $unitTestIdFromUI = $template.TemplateDefinition.UI.Template.UnitTest.DefaultBaseTemplateId
        foreach($unitTestId in $unitTestIdFromUI){
            $foundUnitTestId = $template.TemplateDefinition.BaseTemplates.BaseTemplate.ID | Where-Object { [string]::Compare($_,$unitTestId,$true) -eq 0}
            "Checking UI.Template.UnitTest.DefaultBaseTemplateId [{0}]" -f $unitTestId | Write-Verbose
            if(!$foundUnitTestId){
                $errorsFound = $true
                $msg = ("Missing BaseTemplates.BaseTemplate.ID for UI.Template.UnitTest.DefaultBaseTemplateId [{0}]" -f $unitTestId)
                $unitErrors += $msg
                $msg | Write-Error
            }
        }
    }

    end{
        if($errorsFound){return $unitErrors}
        else{ "no unit test errors found" | Write-Host -ForegroundColor Green}
        "ValidateUnitTestIdFromUI finished" | Write-Verbose 
    }
}
function ValidateVsTemplateExistsForBaseTemplate(){
    param(
        [Parameter(Mandatory=$true)]
        [xml]$template,
        [Parameter(Mandatory=$true)]
        [string]$templatePath
    )
    begin{ "ValidateVsTemplateExistsForBaseTemplate starting" | Write-Verbose }
    process{
        $tempErrors = @()
        # check that the folder exists referred to by 
        $baseTemplatePaths = $template.TemplateDefinition.BaseTemplates.BaseTemplate.VSTemplatePath
        # remove duplicates
        $baseTemplatePaths = ($baseTemplatePaths | select -Unique)
        foreach($baseTempPath in $baseTemplatePaths){
            # ' the file should be next to templates.xml in BaseTmplates\<PATH>
            # Split('\')[1] at the end because the folder in the template path is evidenlty ignored
            # TODO: This needs to be different if checking the source file versus the file in ProgramFiles
            $expectedFolderPath = Join-Path -Path (Get-Item $templatePath).Directory.FullName -ChildPath ("{0}" -f $baseTempPath.Split('\'))
            "Checking for .vstemplate file at [{0}]" -f $expectedFolderPath | Write-Verbose
            if(!(Test-Path $expectedFolderPath)){
                $errorsFound = $true
                $msg = ("Expected to find .vstemplate file at [{0}] but it was not found" -f $expectedFolderPath)
                $tempErrors += $msg
                $msg | Write-Error
            }
        }
    }
    end{
        if($errorsFound){return $tempErrors}
        else{ "All .vstemplate files fond for BaseTemplates" | Write-Host -ForegroundColor Green }
        "ValidateVsTemplateExistsForBaseTemplate finished" | Write-Verbose 
    }
}
function ValidateSourFileRefs(){
    param(
        [Parameter(Mandatory=$true)]
        [xml]$template,
        [Parameter(Mandatory=$true)]
        [string]$templatePath
    )
    begin{ "Validating source file references" | Write-Verbose }
    process{
        $addRemoveFileErrors = @()
        $sourcFileReferences=($template.TemplateDefinition.Rules.Rule.AddFile.Source + $template.TemplateDefinition.Rules.Rule.AddFile.Source)
        foreach($fileRef in $sourcFileReferences){
            $expectedPath = (Join-Path (Get-Item $templatePath).Directory.FullName -ChildPath $fileRef)
            "Checking for source file at [{0}]" -f $expectedPath | Write-Verbose
            if(!(Test-Path $expectedPath)){
                $errorsFound = $true
                $msg = ("Expected to find sourcefile at [{0}] but it was not found" -f $expectedPath)
                $addRemoveFileErrors += $msg
                $msg | Write-Error
            }
        }
    }
    end{
        if($errorsFound){return $addRemoveFileErrors}
        else{ "All spource files found for AddFile/ReplaceFile" | Write-Host -ForegroundColor Green }
        "Done validating source files" | Write-Verbose 
    }
}
function ValidateReferencedRules(){
    param(
        [Parameter(Mandatory=$true)]
        [xml]$template
    )
    begin{"Validating referenced rules" | Write-Verbose}
    process{        
        # check that referrenced rules are defined in the file, skip ones that start with globabl
        $ruleErrors = @()
        $allReferencedRules = @()
        $allReferencedRules += ($template.TemplateDefinition.BaseTemplates.BaseTemplate.ApplyRules.RunRule.RuleId)
        $allReferencedRules += ($template.TemplateDefinition.BaseTemplates.BaseTemplate.ApplyRules.ApplyRules.RunRule.RuleId)
        #de-dup
        $allReferencedRules = ($allReferencedRules | select -Unique)
        foreach($refRule in $allReferencedRules){
            if($refRule.StartsWith("global")){ continue }

            $foundRule = $template.TemplateDefinition.Rules.Rule.ID | Where-Object { [string]::Compare($_,$refRule,$true) -eq 0}
            "Checking for rule [{0}]" -f $refRule | Write-Verbose
            if(!$foundRule){
                $errorsFound = $true
                $msg = ("Missing referenced rule [{0}]" -f $refRule)
                $ruleErrors += $msg
                $msg | Write-Error
            }
        }
    }
    end{
        if($errorsFound){return $ruleErrors}
        else{ "All referenced rules found" | Write-Host -ForegroundColor Green}
        "Validating referenced rules finished" | Write-Verbose 
    }
}
function HasNugetPkgBeenAddedToArray(){
    param(
        [Parameter(Mandatory=$true)]
        $allNugetPackages,
        [Parameter(Mandatory=$true)]
        $nugetPkg
    )

    if($allNugetPackages.Count -le 0){
        return $false
    }

    # there is probably a better way to do this
    if(($allNugetPackages | Where-Object {$_.ID -eq $nugetPkg.ID -and $_.Version -eq $nugetPkg.Version <#-and $_.NugetPackageKey -eq $nugetPkg.NugetPackageKey#>})){
        return $true
    }
    else{
        return $false
    }
}
####### End functions ####### 
#if(Get-Module xml-helpers){
#    "Removing xml-helpers module so that it can be imported again" | Write-Verbose
#    Remove-Module xml-helpers
#}
# Importing modules
#Import-Module .\xml-helpers.psm1
################### Begin script ###################




if(!$templateXsdPath){
    $templateXsdPath = (Join-Path -Path (Get-ScriptDirectory) -ChildPath 'templates.xsd')
}

if(!(Test-Path $templatePath)){
    "Template file not found at [{0}]" -f $templatePath | Write-Error
    exit 1
}

# first run it through the XSD, if it doesn't pass validation we should just quit
$isValid = (IsTemplateXmlValid -templatePath $templatePath -templateXsdPath $templateXsdPath)
if(!$isValid){
    # a standard error message already shows up so we can just send this to verbose
    "The file [{0}] is not valid based on the given xsd [{1}]" -f $templatePath, $templateXsdPath | Write-Verbose
    exit 1
}
else{ "The file is valid based on the xsd provided" | Write-Host -ForegroundColor Green }

$allErrors = @()
[xml]$template = Get-Content $templatePath


if($reportNugetPackages){
    $allNugetPackages = @()
    # for templates.xml we can get NuGet packages from TemplateDefinition.Rules.Rule.AddNuGetPackage
    $nugetPkgFromTemplatesXml = ($template.TemplateDefinition.Rules.Rule.AddNugetPackage)
    foreach($nugetPkg in $nugetPkgFromTemplatesXml){
        if(!($nugetPkg)){
            continue
        }

        $info = New-Object System.Object
        $info | Add-Member -type NoteProperty -name Source -value $templatePath
        $info | Add-Member -type NoteProperty -name ID -value $nugetPkg.ID
        $info | Add-Member -type NoteProperty -name Version -value $nugetPkg.Version
        $info | Add-Member -type NoteProperty -name NugetPackageKey -value $nugetPkg.NugetPackageKey

        # if the item has already been added skip it
        if(!(HasNugetPkgBeenAddedToArray -allNugetPackages $allNugetPackages -nugetPkg $info)){
            "Adding nuget package [{0}{1}]" -f $info.ID, $info.Version | Write-Verbose
            $allNugetPackages += $info
        }
        else{
            "Skipping nuget package [{0}{1}] because its a duplicate" -f $info.ID, $info.Version | Write-Verbose
        }
    }

    $vstemplateFiles = (Get-ChildItem -Path ((Get-Item $templatePath).Directory.FullName) -Include *.vstemplate -Recurse)
    foreach($vsTemplateFile in $vstemplateFiles){
        [xml]$vsTempXml=(Get-Content $vstemplateFile)
        foreach($pkg in $vsTempXml.VSTemplate.WizardData.packages.package){            
            $info = New-Object System.Object
            $info | Add-Member -type NoteProperty -name Source -value $vsTemplateFile
            $info | Add-Member -type NoteProperty -name ID -value $pkg.ID
            $info | Add-Member -type NoteProperty -name Version -value $pkg.Version
            $info | Add-Member -type NoteProperty -name NugetPackageKey -value "vstemplate"

            if(!(HasNugetPkgBeenAddedToArray -allNugetPackages $allNugetPackages -nugetPkg $info)){
                "Adding nuget package [{0}{1}]" -f $info.ID, $info.Version | Write-Verbose
                $allNugetPackages += $info
            }
            else{
                "Skipping nuget package [{0}{1}] because its a duplicate" -f $info.ID, $info.Version | Write-Verbose
            }
        }
    }

    $allNugetPackages = ($allNugetPackages | Sort-Object -Property ID)

    # print out all the nuget packages found
    $seperator = ","
    "ID$seperator Version" | Write-Host    
    
    foreach($nugetPkg in $allNugetPackages){
        "{1}{0}{2}" -f $seperator, $nugetPkg.ID,$nugetPkg.Version | Write-Host -ForegroundColor Cyan
    }

    # assume that the .vstemplate files are contained under the same folder as templates.xml
}
return




$allErrors += ValidateBaseTemplateId -template $template
$allErrors += ValidateUnitTestIdFromUI -template $template
$allErrors += ValidateVsTemplateExistsForBaseTemplate -template $template -templatePath $templatePath
$allErrors +=  ValidateReferencedRules -template $template
$allErrors += ValidateSourFileRefs -template $template -templatePath $templatePath

if($allErrors.Count -gt 0){
    "There were errors" | Write-Error
    $allErrors | Write-Host -BackgroundColor Black -ForegroundColor Red
}


#Remove-Module xml-helpers























