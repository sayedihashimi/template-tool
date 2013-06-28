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
        # $foundElement = $proj.Project.ItemGroup.Loc | Where-Object {$_.Include.Contains($xmlPath)}

        foreach($baseTempId in $baseTemplateIdsFromTemplate){
            # check to see that there is a corresponding value for BaseTemplates.BaseTemplate.ID
            $foundBaseTempId = $template.TemplateDefinition.BaseTemplates.BaseTemplate.ID | Where-Object { [string]::Compare($_,$baseTempId,$true) -eq 0}
            if(!$foundBaseTempId){
                $errorFound = $true
                $msg = ("Missing BaseTemplates.BaseTemplate.ID value for UI.Template.BaseTemplateID [{0}]" -f $baseTempId)
                $baseTempErrors += $msg
                $msg | Write-Error
            }
        }

        
    }
    End{
        if($errorFound){
            return $baseTempErrors
        }
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

"isValid: {0}" -f $isValid | Write-Host -ForegroundColor Yellow -BackgroundColor Black

$allErrors = @()
[xml]$template = Get-Content $templatePath

$baseErrors = ValidateBaseTemplateId -template $template
if($baseErrors){
    $allErrors += $baseErrors
}

Remove-Module xml-helpers























