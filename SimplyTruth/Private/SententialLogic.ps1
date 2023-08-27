function TestSentenceAsValidSL {
    param([parameter(Mandatory, ValueFromPipeline)][ValidateNotNullOrEmpty()][string]$Sentence)

    if($Sentence.Replace(" ","").Length -lt 3) {
        return "SL expression is too short"
    }

    #determine if invalid tokens in string
    $invalidTokenRegex = "[^A-Z \{\}\[\]\(\)>&~v=]"
    $InvalidTokens = $Sentence | Select-String -CaseSensitive -AllMatches -Pattern $invalidTokenRegex
    if($InvalidTokens){
        Write-Output "Invalid Tokens:"
        return $InvalidTokens
    }
}

Class SL {
    static [bool] And($first, $second) {
        return ($first -and $second)
    }
    static [bool] Or($first, $second) {
        return ($first -or $second)
    }
    static [bool] IfThen($first, $second) {
        return [SL]::Or([SL]::Not($first), [SL]::And($first, $second))
    }
    static [bool] IFF($first, $second) {
        return [SL]::Or([SL]::And($first, $second), [SL]::And([SL]::Not($first), [SL]::Not($second)))
    }
    static [bool] Not($first) {
        return (-not($first))
    }
}

class SLAtomic {
    [string]$token
    SLAtomic(){}
    SLAtomic([string]$x){$this.token = $x}
    [string]ToString() {return $this.token}
    [string]ToPS() {return '$' + $this.token}
}

class SLConnective {
    $first
    $second #not used for negation
    [string]$connective
    [string]$startDelim = "("
    [string]$endDelim = ")"
    [string] ToString() {
        if($this.connective -eq "~") { return ("{0}{1}" -f $this.connective, $this.first) }
        else {
            return ("{3}{1}{0}{2}{4}" -f $this.connective, $this.first, $this.second, $this.startDelim, $this.endDelim)
        }
    }
    [string] ToPS() {
        
        if($this.connective -eq "&") {
            return ("[SL]::And({0}, {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq "v") {
            return ("[SL]::Or({0}, {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq ">") {
            return ("[SL]::IfThen({0}, {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq "=") {
            return ("[SL]::IFF({0}, {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq "~") {
            return ("[SL]::Not({0})" -f $this.first.ToPS())
        }
        else {
            throw "invalid connective: $($this.connective)"
        }
    }
}

class SLSentence {
    [SLConnective] $MainConnective
    [string[]] $SentenceTokens = @()
    hidden [System.Collections.Generic.Queue[char]]$ParseQueue = [System.Collections.Generic.Queue[char]]::new()

    SLSentence([string]$sentence) {
        $Sentence = $Sentence.Replace(" ","")
        $connectiveCount = $Sentence.Length - $Sentence.Replace("&","").Replace("v","").Replace(">","").Replace("=","").Length
        $delimCount = $Sentence.Length - $Sentence.Replace("(","").Replace("[","").Replace("{","").Length
        $removal = $delimCount - $connectiveCount + 1
        if($removal -gt 0) {
            $Sentence = $Sentence.Substring($removal, ($Sentence.Length-($removal * 2)))
        }
        
        $Sentence.ToCharArray().foreach({$null = $this.ParseQueue.Enqueue($_)})
        $this.MainConnective = $this.ParseConnective([SLConnective]::new())
    }

    hidden [SLConnective]ParseConnective([SLConnective]$current) {
        while($this.parseQueue.Count -gt 0) {
            $token = $this.parseQueue.Dequeue()
            $remaining = $this.ParseQueue.ToArray() -join ""
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
            elseif(
                ($token -eq ")" -and ($current.startDelim -eq "(")) -or
                ($token -eq "]" -and ($current.startDelim -eq "[")) -or
                ($token -eq "}" -and ($current.startDelim -eq "{"))
                ) {}
            else {
                throw "Invalid token '$token' before '$remaining' -- $current"
            }
            
            if($token -in "(","{","[","~"){
                $nConnective = [SLConnective]::new()
                if($token -eq "~") {
                    $nConnective.connective = $token
                } else {
                    $nConnective.startDelim = $token
                }
                if($null -eq $current.first) {
                    $current.first = $this.ParseConnective($nConnective)
                }
                else {
                    $current.second = $this.ParseConnective($nConnective)
                }
            }
            elseif($token -in ")","}","]") {
                $current.endDelim = $token
                return $current
            }
            elseif($token -in "&","v",">","=") {
                $current.connective = $token                
            }
            else {
                $this.AddSentenceToken($token)
                if($null -eq $current.first) {
                    $current.first = [SLAtomic]::new($token)
                    if($current.connective -eq "~") {
                        return $current
                    }
                }
                else {
                    $current.second = [SLAtomic]::new($token)
                }
            }
        }
        return $current
    }

    [string] ToString() {
        return $this.MainConnective.ToString().SubString(1, $this.MainConnective.ToString().Length -2)
    }
    
    AddSentenceToken([string]$t) {
        if(-not $this.SentenceTokens.Contains($t.ToUpper())){
            $this.SentenceTokens += $t
        }
    }

    [bool]Invoke([hashtable]$tokenValues) {
        [string]$logicSentence = $tokenValues.Keys.foreach({'$' + $_.ToUpper() + "=$" + [bool]$tokenValues[$_] + "; "}) -join ""
        $logicSentence += $this.MainConnective.ToPS()
        return (Invoke-Expression $logicSentence)
    }
}