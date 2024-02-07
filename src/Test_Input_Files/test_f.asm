; Test file f
; Expressions with bitwise operators, strings

.ORG $1000
T_STRING:
.BYTE "Test string; ASCII values $FF,0577,91\0\"\\",0
T_STRING_END:
.ORG $0000

P_READ =   %00000001
P_WRITE =  %00000010
P_INPUT =  %11111111
P_OUTPUT = %00000000
P_MASK =   %10101010

PORT_A = $5150
PORT_B = PORT_A + 2
DDR_A = PORT_A + 1
DDR_B = PORT_B + 1

SET_MODE_PORT = $5250

LDA #P_INPUT
STA DDR_A
LDA #P_OUTPUT
STA DDR_B

LDA #[P_READ | P_WRITE]
STA SET_MODE_PORT

LDA #[P_INPUT ^ P_MASK]
STA $F1
LDA #[P_INPUT & P_MASK ^ P_READ]
STA $F2

LDA #[T_STRING_END - T_STRING]
STA $F0
LDX $F0

WRITE_LOOP:
	LDA T_STRING,X
	STA PORT_A
	INX
	DEC $F0
	BNE WRITE_LOOP

LDA #"x"
STA PORT_A

BRK
