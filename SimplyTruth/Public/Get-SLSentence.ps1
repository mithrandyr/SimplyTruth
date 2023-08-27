function Get-SLSentence {
    [CmdletBinding()]
    param([parameter(Mandatory, ValueFromPipeline)][ValidateNotNullOrEmpty()][string]$Sentence)
    if(-not (Test-SLSentence $sentence)) {
        Test-SLSentence $sentence -ShowErrors
        return
    }

    return [SLSentence]::new($Sentence)
}