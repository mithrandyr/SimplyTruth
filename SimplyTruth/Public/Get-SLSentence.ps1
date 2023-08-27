function Get-SLSentence {
    [CmdletBinding()]
    param([parameter(Mandatory, ValueFromPipeline)][ValidateNotNullOrEmpty()][string]$Sentence)
    if(-not (Test-SLSentence $sentence)) {
        Test-SLSentence $sentence -ShowErrors
        throw "Invalid SL Sentence"
    }

    return [SLSentence]::new($Sentence)
}