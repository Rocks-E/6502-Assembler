; Test file C
; Check that all addressing types are working

; Accumulator						Done
; Absolute							Done
; Absolute X						Done
; Absolute Y						Done
; Immediate							Done
; Implied 							Done
; Indirect							Done
; Indirect X						Done
; Indirect Y						Done
; Relative							Done
; Zeropage							Done
; Zeropage X						Done
; Zeropage Y						Done

LOAD:
	LDA #0577 						; Immediate 	(A9)
	LDA 15							; Zeropage		(A5)
	LDA 150,X						; Zeropage X	(B5)
	LDA 300							; Absolute		(AD)
	LDA 350,X						; Absolute X	(BD)
	LDA 631,Y						; Absolute Y	(B9)
	LDA (123,X)						; Indirect X	(A1)
	LDA (19),Y						; Indirect Y	(B1)
						
ACC:					
	ASL A							; Accumulator	(0A)
						
SET:					
	SEC								; Implied		(38)
	
RELATIVE:
	BNE ACC							; Relative		(D0)
	
INDIRECT:
	JMP (%0011001111001100)			; Indirect		(6C)
	
ZPG_Y:
	STX 50,Y						; Zeropage Y	(96)