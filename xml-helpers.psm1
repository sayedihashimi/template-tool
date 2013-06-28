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