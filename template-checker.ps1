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

[xml]$template = Get-Content $templatePath

# first run it through the XSD, if it doesn't pass validation we should just quit
$isValid = (IsTemplateXmlValid -templatePath $templatePath -templateXsdPath $templateXsdPath)
if(!$isValid){
    # a standard error message already shows up so we can just send this to verbose
    "The file [{0}] is not valid based on the given xsd [{1}]" -f $templatePath, $templateXsdPath | Write-Verbose
    exit 1
}

"isValid: {0}" -f $isValid | Write-Host -ForegroundColor Yellow -BackgroundColor Black





Remove-Module xml-helpers