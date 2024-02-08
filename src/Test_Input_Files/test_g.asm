; Test file g
; Negation and bitwise NOT

ONE_BYTE   = $45
TWO_BYTE   = 1400
NOT_O      = ~ONE_BYTE
N_O_PLUS_T = -[ONE_BYTE + TWO_BYTE]

LDA NOT_O
LDA N_O_PLUS_T