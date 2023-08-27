# SimplyTruth
PowerShell module for generating truth tables and evaluating whether a sentence in SL is TF-true, TF-false or TF-indeterminate

# Sentential Logic
## Language
- Grouping delimeters: () or [] or {}
- Sentence Tokens: UpperCase A-Z
- Spaces are ignored
- Outter Delimeter(s) is stripped.
    - "(AvB)" becomes "AvB" 
    - "[(A>B) & C]" becomes "(A>B) & C" 
    - "(((A = B)))" becomes "A=B"
- Sentential Connectives

|in Module|Connective| English|
|-|-|-|
| ~ | Negation ('tilde')| "Not" |
| & | Conjunction ('ampersand') | "And" |
| v | Disjunction ('wedge') | "Or" |
| > | Material Conditional ('horseshoe') | "If Then" |
| = | Material Biconditional ('triple bar') | "If and Only If" |

- Example Sentences
    - A v B
    - (A v B)
    - A > B
    - A & B
    - A = B
    - ~B & A

## Commands
- Test-SLSentence -- basic evaluation of whether expression is valid
- Get-SLSentence -- converts expression to SLSentence object (parses it)
- Invoke-SLSentence -- takes SLSentence or expression and determines its truth-value based upon the supplied values for the Sentence Tokens
- Get-SLTruthTable -- generates a truthtable for an expression or SLSentence.


# TODO
- Rename repo to "SimplyLogic"
- Update TruthTable output to show as T or F instead of True or False
- Update TruthTable output to show all subconnectives and their values
- Add help to commands
- Improve Validation (too many delimeters for connectives, etc)