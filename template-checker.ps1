Param(
  [Parameter(Mandatory=$true)]
  [string]$templatePath,
  [Parameter(Mandatory=$true)]
  [string]$templateXsdPath
)

######## Begin functions ######## 
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
        $templateDirectory = 
        foreach($baseTempPath in $baseTemplatePaths){
            # ' the file should be next to templates.xml in BaseTmplates\<PATH>
            # Split('\')[1] at the end because the folder in the template path is evidenlty ignored
            $expectedFolderPath = Join-Path -Path (Get-Item $templatePath).Directory.FullName -ChildPath ("BaseTemplates\{0}" -f $baseTempPath.Split('\')[1])
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

####### End functions ####### 
if(Get-Module xml-helpers){
    "Removing xml-helpers module so that it can be imported again" | Write-Verbose
    Remove-Module xml-helpers
}
# Importing modules
Import-Module .\xml-helpers.psm1
################### Begin script ###################
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

$baseErrors = ValidateBaseTemplateId -template $template
$allErrors += $baseErrors

$unitErrors = ValidateUnitTestIdFromUI -template $template
$allErrors += $unitErrors

$tempErrors = ValidateVsTemplateExistsForBaseTemplate -template $template -templatePath $templatePath
$allErrors += $unitErrors











Remove-Module xml-helpers























