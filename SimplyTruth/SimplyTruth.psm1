$script:InvalidTokenRegex = "[^A-Z \{\}\[\]\(\)>&~v=]"

function Test-STSyntax{
    param([parameter(Mandatory, ValueFromRemainingArguments)][ValidateNotNullOrEmpty()][string]$Sentence,
    [switch]$ShowErrors)

    #determine if invalid tokens in string
    $InvalidTokens = $Sentence | Select-String -CaseSensitive -AllMatches -Pattern $script:InvalidTokenRegex
    if($InvalidTokens){
        if($ShowErrors){
            Write-Output $InvalidTokens
        }
        return $false   
    }
    if($Sentence.Replace(" ","").Length -lt 3) {
        if($ShowErrors) { Write-Warning "SL expression is too short"}
        return $false
    }
    
    return $true
}

function Invoke-STConditional {
    param([parameter(Mandatory)][bool]$first, [parameter(Mandatory)][bool]$second)
    return (-not $first) -or ($first -and $second)
}

function Invoke-STBiConditional {
    param([parameter(Mandatory)][bool]$first, [parameter(Mandatory)][bool]$second)
    return ($first -and $second) -or (-not $first -and -not $second)
}

function Invoke-STConjunction {
    param([parameter(Mandatory)][bool]$first, [parameter(Mandatory)][bool]$second)
    return ($first -and $second)
}
function Invoke-STDisjunction {
    param([parameter(Mandatory)][bool]$first, [parameter(Mandatory)][bool]$second)
    return ($first -or $second)
}

function Invoke-STNegation {
    param([parameter(Mandatory)][bool]$first)
    return (-not $first)
}

function Parse-STSentence {
    [cmdletBinding()]
    param([parameter(Mandatory, ValueFromRemainingArguments)][ValidateNotNullOrEmpty()][string]$Sentence)
    if(-not (Test-STSyntax $sentence)) { return }

    $parseQueue = [System.Collections.Generic.Queue[char]]::new()
    $Sentence.Replace(" ","").ToCharArray().foreach({$null = $parseQueue.Enqueue($_)})
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
            elseif($token -in ")","}","]") {}
            else {
                throw "Invalid token '$token' before '$remaining'"
            }
            
            if($token -in "(","{","[","~"){
                $nGroup = [SLGroup]::new()
                if($token -eq "~") {
                    Write-Verbose "Negation '$token' -- $remaining"
                    $nGroup.connective = $token
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
    
    return ParseGroup $parseableSentence    
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
        if($null -eq $this.second) {
            return ("{0}{1}" -f $this.connective, $this.first)
        }
        else {
            return ("{3}{1}{0}{2}{4}" -f $this.connective, $this.first, $this.second, $this.startDelim, $this.endDelim)
        }
    }
    [string] ToPS() {
        if($this.connective -eq "~") {
            return ("(Invoke-STNegation {0})" -f $this.first.ToPS())
        }
        elseif($this.connective -eq "&") {
            return ("(Invoke-STConjunction {0} {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq "v") {
            return ("(Invoke-STDisjunction {0} {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq ">") {
            return ("(Invoke-STConditional {0} {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        elseif($this.connective -eq "=") {
            return ("(Invoke-STBiConditional {0} {1})" -f $this.first.ToPS(), $this.second.ToPS())
        }
        else {
            throw "invalid connective: $($this.connective)"
        }
    }
}