function Invoke-SLSentence {
    [CmdletBinding()]
    param([parameter(Mandatory, ValueFromPipeline, ParameterSetName="raw", position=0)][ValidateNotNullOrEmpty()][string]$Sentence
        , [parameter(Mandatory, ValueFromPipeline, ParameterSetName="obj", position=0)][ValidateNotNullOrEmpty()][SLSentence]$SL
        , [hashtable]$Parameters = @{}
    )
    if($pscmdlet.ParameterSetName -eq "raw") { $SL = Get-SLSentence $sentence }

    $SL.Invoke($parameters)
}