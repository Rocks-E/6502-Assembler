STA [$1050],X
LDA #[$1050]
STA [$1050]
STA [$96]
LDA [$2F]
STA [$1050],X
BNE $0A
BNE LABEL
ORA #[$8E]
LDA #$AF
.BYTE $50,[$1050],[$2F]
LABEL:
JMP LABEL