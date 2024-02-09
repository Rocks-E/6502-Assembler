; Test file g
; Negation and bitwise NOT, left and right arithmetic shifts

OFFSET 	   = 2

ONE_BYTE   = $45
TWO_BYTE   = 1400
NOT_O      = ~ONE_BYTE
N_O_PLUS_T = -[ONE_BYTE + TWO_BYTE]

LS_O	   = ONE_BYTE << OFFSET
RS_T	   = TWO_BYTE >> OFFSET

LDA NOT_O
LDA N_O_PLUS_T

STA RS_T
ADC LS_O