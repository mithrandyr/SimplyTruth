$script:InvalidTokenRegex = "[^A-Z \{\}\[\]\(\)>&~v=]"

function Test-SLSyntax {
    param([parameter(Mandatory, ValueFromPipeline)][ValidateNotNullOrEmpty()][string]$Sentence,
    [switch]$Quiet)

    #determine if invalid tokens in string
    $InvalidTokens = $Sentence | Select-String -CaseSensitive -AllMatches -Pattern $script:InvalidTokenRegex
    if($InvalidTokens){
        if($Quiet) { return $false }
        else {
            Write-Output $InvalidTokens
        }
    }
    if($Sentence.Replace(" ","").Length -lt 3) {
        if($Quiet) { return $false }
        else {
            Write-Output "SL expression is too short"
        }
    }
    if($Quiet) { return $true }
}

function Invoke-SLConditional {
    param([parameter(Mandatory)][bool]$first, [parameter(Mandatory)][bool]$second)
    return (-not $first) -or ($first -and $second)
}

function Invoke-SLBiconditional {
    param([parameter(Mandatory)][bool]$first, [parameter(Mandatory)][bool]$second)
    return ($first -and $second) -or (-not $first -and -not $second)
}

function Invoke-SLConjunction {
    param([parameter(Mandatory)][bool]$first, [parameter(Mandatory)][bool]$second)
    return ($first -and $second)
}
function Invoke-SLDisjunction {
    param([parameter(Mandatory)][bool]$first, [parameter(Mandatory)][bool]$second)
    return ($first -or $second)
}

function Invoke-SLNegation {
    param([parameter(Mandatory)][bool]$first)
    return (-not $first)
}

function Get-SLSentence {
    [CmdletBinding()]
    param([parameter(Mandatory, ValueFromPipeline)][ValidateNotNullOrEmpty()][string]$Sentence)
    if(-not (Test-SLSyntax $sentence -Quiet)) { Write-Warning "Invalid Syntax!"; return }

    $parseQueue = [System.Collections.Generic.Queue[char]]::new()
    $Sentence.Replace(" ","").ToCharArray().foreach({$null = $parseQueue.Enqueue($_)})
    $SLSentence = [SLSentence]::new()

    function ParseGroup ([SLGroup]$current) {
        if($null -eq $current) {
            Write-Verbose "Creating Group"
            $current = [SLGroup]::new()
        }
        while($parseQueue.Count -gt 0) {
            $token = $parseQueue.Dequeue()
            $remaining = $parseQueue.ToArray() -join ""
            if(
                ($null -eq $current.first) -and
                ($token -notin "&","v",">","=",")","}","]")) {}
            elseif(
                ($null -eq $current.connective) -and
                ($token -in "&","v",">","=")) {}
            elseif(
                (($null -eq $current.second) -and
                $current.connective -ne "~" -and
                ($token -notin "&","v",">","=",")","}","]"))) {}
            elseif($token -eq $current.startDelim) {}
            else {
                throw "Invalid token '$token' before '$remaining'"
            }
            
            if($token -in "(","{","[","~"){
                $nGroup = [SLGroup]::new()
                if($token -eq "~") {
                    Write-Verbose "Negation '$token' -- $remaining"
                    $nGroup = [SLNegation]::new()
                } else {
                    Write-Verbose "New Group '$token' -- $remaining"
                    $nGroup.startDelim = $token
                }
                if($null -eq $current.first) {
                    $current.first = ParseGroup $nGroup
                }
                else {
                    $current.second = ParseGroup $nGroup
                }
            }
            elseif($token -in ")","}","]") {
                $current.endDelim = $token
                Write-Verbose "finishing group '$token' -- $remaining"
                return $current
            }
            elseif($token -in "&","v",">","=") {
                Write-Verbose "add connective '$token' -- $remaining"
                $current.connective = $token                
            }
            else {
                if($null -eq $current.first) {
                    $SLSentence.AddSentenceToken($token)
                    $current.first = [SLToken]::new($token)
                    if($current.connective -eq "~") {
                        Write-Verbose "finish negation '$token' -- $remaining"
                        return $current
                    }
                    else {
                        Write-Verbose "Add First SL '$token' -- $remaining"
                    }
                }
                else {
                    Write-Verbose "Add Second SL '$token' -- $remaining"
                    $current.second = [SLToken]::new($token)
                }
            }
        }
        return $current
    }
    $SLSentence.Sentence = ParseGroup $parseableSentence
    return $SLSentence
}

function Invoke-SLSentence {
    [CmdletBinding()]
    param([parameter(Mandatory, ValueFromPipeline, ParameterSetName="raw", position=0)][ValidateNotNullOrEmpty()][string]$Sentence
        , [parameter(Mandatory, ValueFromPipeline, ParameterSetName="obj", position=0)][ValidateNotNullOrEmpty()][SLSentence]$SL
        , [hashtable]$Parameters = @{}
    )
    if($pscmdlet.ParameterSetName -eq "raw") { $SL = Get-SLSentence $sentence }

    $SL.Invoke($parameters)
}

function Get-SLTruthTable {
    [CmdletBinding()]
    param([parameter(Mandatory, ValueFromPipeline, ParameterSetName="raw", position=0)][ValidateNotNullOrEmpty()][string]$Sentence
        , [parameter(Mandatory, ValueFromPipeline, ParameterSetName="obj", position=0)][ValidateNotNullOrEmpty()][SLSentence]$SL
    )
    if($pscmdlet.ParameterSetName -eq "raw") { $SL = Get-SLSentence $sentence }


}

class SLToken {
    [string]$token
    SLToken(){}
    SLToken([string]$x){$this.token = $x}
    [string]ToString() {return $this.token}
    [string]ToPS() {return '$' + $this.token}
}

class SLGroup {
    $first
    $second #not used for negation
    [string]$connective
    [string]$startDelim = "("
    [string]$endDelim = ")"
    [string] ToString() {
        return ("{3}{1}{0}{2}{4}" -f $this.connective, $this.first, $this.second, $this.startDelim, $this.endDelim)
    }
    [string] ToPS() {
        
        if($this.connective -eq "&") {
            return ("(Invoke-SLConjunction {0} {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq "v") {
            return ("(Invoke-SLDisjunction {0} {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq ">") {
            return ("(Invoke-SLConditional {0} {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq "=") {
            return ("(Invoke-SLBiconditional {0} {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        else {
            throw "invalid connective: $($this.connective)"
        }
    }
}

class SLNegation:SLGroup {
    SLNegation(){
        $this.connective = "~"
    }
    [string] ToString() {
        return ("{0}{1}" -f $this.connective, $this.first)
    }
    [string] ToPS() {
        return ("(Invoke-SLNegation {0})" -f $this.first.ToPS())
    }
}

class SLSentence {
    [SLGroup] $Sentence = [SLGroup]::new()
    [string[]] $SentenceTokens = @()

    [string] ToString() {
        return $this.sentence.ToString().SubString(1, $this.sentence.Length -2)
    }
    
    AddSentenceToken([string]$t) {
        if(-not $this.SentenceTokens.Contains($t.ToUpper())){
            $this.SentenceTokens += $t
        }
    }

    [bool]Invoke([hashtable]$tokenValues) {
        [string]$logicSentence = $tokenValues.Keys.foreach({'$' + $_.ToUpper() + "=$" + [bool]$tokenValues[$_] + "; "}) -join ""
        $logicSentence += $SL.ToPS()
        return (Invoke-Expression $logicSentence)
    }
}

Class SLTruthTable {
    [Ordered[]]$AtomicSL = @()
    SLTruthTable([string[]]$Tokens) {
        foreach($x in (1..[math]::pow(2,3))){
            $row = [Ordered]@{}
            $i = 1
            foreach($t in $Tokens) {
                $row.$t = $x
            }
            $this.AtomicSL += $row

            <#
            to build truth table (assume A, B, C)
            1) build out initial objects (math::pow(2,3))
                for each object, set A = [bool]$_ % 2
            2) Sort, by A -descending
            3) For each in list, set B = [bool]$_ % 2
            4) Sort, by B, A -descending
            5) For each in list, set B = [bool]$_ % 2
            
            #>
        }
    }
}