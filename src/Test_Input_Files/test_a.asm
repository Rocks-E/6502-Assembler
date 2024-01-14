; Test file A
; Standard ASM with weird formatting, should assemble normally
					  STA    TEST   ,  X	;Comment = 1 
; Remove
	TEST = $1050

; Change to LDA #$1050
	LDA #TEST ; #TEST = #$(10)50

; Change to STA $1050
	STA TEST
; Change to STA $96
	STA D2
; Change to LDA $2F
	LDA O1
	STA TEST,X

; Remove ($96)
D1 = D2 = D3 = 150

; Remove ($2F)
O1 = 057
; Remove ($8E)
B1 = B2 = %10001110

		  bnE 012
									bne label

; Change to ORA #$8E
	ORA #B2
	LDA #$af
	  .byTe $50,TEST,o1
	
; No changes
LABEL:

; No changes
	JMP LABEL