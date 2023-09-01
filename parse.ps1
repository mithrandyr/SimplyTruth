param([string]$english)

[SLSentence]::new($english)


Class SL {
    static [bool] And($first, $second) {
        return ($first -and $second)
    }
    static [bool] Or($first, $second) {
        return ($first -or $second)
    }
    static [bool] IfThen($first, $second) {
        return [SL]::Or([SL]::Not($first), $second)
    }
    static [bool] IFF($first, $second) {
        return [SL]::Or([SL]::And($first, $second), [SL]::And([SL]::Not($first), [SL]::Not($second)))
    }
    static [bool] Not($first) {
        return (-not($first))
    }
}

class SLbase {
    [string]ToString() { throw "Must Overide!" }
    [string]ToPS() { throw "Must Overide!" }
}
class SLAtomic:SLbase {
    [string]$token
    SLAtomic(){}
    SLAtomic([string]$x){ $this.token = $x }
    [string]ToString() { return $this.token }
    [string]ToPS() { return '$' + $this.token }
}

class SLConnective:SLbase {
    $first
    $second #not used for negation
    [string]$connective
    [string]$startDelim = "("
    [string]$endDelim = ")"
    
    SLConnective() {}
    SLConnective([string]$c) { $this.connective = $c }
    [string] ToString() {
        if($this.connective -eq "~") { return ("{0}{1}" -f $this.connective, $this.first) }
        if($null -eq $this.connective) { return $this.first }
        else {
            return ("{3}{1}{0}{2}{4}" -f $this.connective, $this.first, $this.second, $this.startDelim, $this.endDelim)
        }
    }
    [string] ToPS() {
        
        if($this.connective -eq "&") {
            return ("[SL]::And({0}, {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq "|") {
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
        elseif(($null -eq $this.connective) -and ($null -eq $this.second)) {
            return $this.first.ToPS()
        }
        else {
            throw "invalid connective: $($this.connective)"
        }
    }
}

class SLSentence {
    [SLbase] $MainConnective
    [string[]] $SentenceTokens = @()
    hidden [System.Collections.Generic.Queue[char]]$ParseQueue = [System.Collections.Generic.Queue[char]]::new()
    hidden [string]$theSentence
    hidden [int]$curIndex = 0

    hidden [string[]]$lConnnective = "&","|",">","="
    hidden [string[]]$lOpenGroup = "(","[","{"
    hidden [string[]]$lCloseGroup = ")","]","}"

    SLSentence([string]$sentence) {
        $Sentence = $Sentence.Replace(" ","").ToUpper()
        $Sentence.ToCharArray().foreach({$null = $this.ParseQueue.Enqueue($_)})
        $this.theSentence = $Sentence
        if($this.Validate($Sentence)) {
            $this.MainConnective = $this.Parse()
            if($null -eq $this.MainConnective.connective) { $this.MainConnective = $this.MainConnective.first }
        }
        #$this.MainConnective = $this.ParseConnective([SLConnective]::new())
    }

    hidden [bool]Validate([string]$sentence) {
        $totalLength = $sentence.Length
        $connCount = $totalLength - $sentence.Replace("&","").Replace("|","").Replace(">","").Replace("=","").Length
        $delimCount = $totalLength - $sentence.Replace("(","").Replace("[","").Replace("{","").Length

        if($delimCount -gt $connCount) { throw "too many delimeters" }
        if($sentence[0] -in $this.lConnnective + $this.lCloseGroup) { throw "invalid start of sentence" }
        if($sentence[-1] -in $this.lConnnective + $this.lOpenGroup + "~") { throw "invalid end of sentence" }

        return $true
    }

    hidden [SLConnective]Parse(){
        $current = [SLConnective]::new()
        while($this.curIndex -lt $this.theSentence.Length) {
            $token = $this.theSentence[$this.curIndex]
            $prev = if($this.curIndex -gt 0) { $this.theSentence[$this.curIndex - 1] }
            $next = if($this.curIndex -lt $this.theSentence.Length) { $this.theSentence[$this.curIndex + 1] }
            $soFar = $this.theSentence[0..$this.curIndex] -join ""
            $this.curIndex += 1
            
            if($token -eq "~") {
                if($prev -in $this.lCloseGroup -or $prev -match "A-Z"){
                    throw "Negation cannot follow '$prev' in '$soFar'"
                }

                # need to rethink this.. maybe support passing in Negation...
                $nConn = [SLConnective]::new("~")
                if($next -in $this.lOpenGroup) {
                    $this.curIndex += 1
                    $nConn.first = $this.Parse()
                }
                elseif($next -eq "~") {
                    $nConn.first = $this.Parse()
                }
                else {
                    $this.AddSentenceToken($next)
                    $nConn.first = [SLAtomic]::new($next)
                    $this.curIndex += 1
                }
                
                if($null -eq $current.first) { $current.first = $nConn }
                else { $current.second = $nConn }
            }
            elseif($token -in $this.lConnnective){
                if($prev -in $this.lOpenGroup + $this.lConnnective + "~") {
                    throw "Connective cannot follow '$prev' in '$soFar'"
                }
                $current.connective = $token
            }
            elseif($token -in $this.lOpenGroup){
                if($prev -in $this.lCloseGroup -or $prev -match "A-Z") {
                    throw "Open Group cannot follow '$prev' in '$soFar'"
                }
                $nConn = $this.Parse()
                $nConn.startDelim = $token
                if($null -eq $current.first) { $current.first = $nConn }
                else { $current.second = $nConn }
            }
            elseif($token -in $this.lCloseGroup) {
                if($prev -in $this.lConnnective + $this.lOpenGroup + "~") {
                    throw "Close Group cannot follow '$prev' in '$soFar'"
                }
                elseif($null -eq $current.connective) { throw "Close Group must contain a connective - $soFar" }
                elseif($null -eq $current.second) { throw "Close group must contain 2 connectives - $soFar" }
                $current.endDelim = $token
                return $current
            }
            else {
                $this.AddSentenceToken($token)
                if($null -eq $current.first) { $current.first = [SLAtomic]::new($token) }
                else { $current.second = [SLAtomic]::new($token) }
            }
        }

        return $current
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
                throw "Invalid token '$token' before '$remaining'"
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

    hidden AddSentenceToken([string]$t) {
        if(-not $this.SentenceTokens.Contains($t.ToUpper())){
            $this.SentenceTokens += $t
        }
    }

    [string] ToPS() {
        return $this.MainConnective.ToPS()
    }
    

    [bool]Invoke([hashtable]$tokenValues) {
        [string]$logicSentence = $tokenValues.Keys.foreach({'$' + $_.ToUpper() + "=$" + [bool]$tokenValues[$_] + "; "}) -join ""
        $logicSentence += $this.MainConnective.ToPS()
        return (Invoke-Expression $logicSentence)
    }
}