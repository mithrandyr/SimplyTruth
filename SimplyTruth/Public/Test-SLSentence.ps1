function Test-SLSentence {
    param([parameter(Mandatory, ValueFromPipeline)][ValidateNotNullOrEmpty()][string]$Sentence,
    [switch]$ShowErrors)

    $results = TestSentenceAsValidSL $Sentence

    if($ShowErrors) {
        return $results
    }
    else {
        return ($null -eq $results)
    }
}