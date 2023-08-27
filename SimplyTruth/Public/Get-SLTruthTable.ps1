function Get-SLTruthTable {
    [CmdletBinding()]
    param([parameter(Mandatory, ValueFromPipeline, ParameterSetName="raw", position=0)][ValidateNotNullOrEmpty()][string]$Sentence
        , [parameter(Mandatory, ValueFromPipeline, ParameterSetName="obj", position=0)][ValidateNotNullOrEmpty()][SLSentence]$SL
    )
    if($pscmdlet.ParameterSetName -eq "raw") { $SL = Get-SLSentence $sentence }

    $Table = (1..[Math]::Pow(2,$SL.SentenceTokens.Count)).foreach({
        [PSCustomObject]@{}
    })
    
    $sort = @()
    foreach($t in $SL.SentenceTokens | Sort-Object) {
        $i = 0
        foreach($row in $table | Sort-Object $sort -Descending) {
            $i +=1
            $row | Add-Member -NotePropertyName $t -NotePropertyValue ([bool]($i % 2))
        }
        $sort += $t
    }

    foreach($row in $table) {
        $n = $SL.ToString()
        $ht = @{}
        $SL.SentenceTokens.foreach({$ht.$_ = $row.$_})
        $v = $SL | Invoke-SLSentence -Parameters $ht
        $row | Add-Member -NotePropertyName $n -NotePropertyValue $v
    }
    $table | Sort-Object $sort -Descending

}
