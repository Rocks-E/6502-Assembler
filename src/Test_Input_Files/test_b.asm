; Test file B
; Expressions and directives
.org p_player 													;.ORG $5000
.word 30,10,5 													;.WORD $1E,$0A,$05

.org 0 															;.ORG 0
LDA [p_obj + p_obj_hp]											;LDA [$5150 + $00]
ADC [p_player + p_player_at]									;ADC [$5000 + $04
STA p_obj + p_obj_hp											;STA $5150 + $00
LDA #[p_obj - p_player]											;LDA #[$5150 - $5000]
ADC #[10 + 1 * [p_obj_mp - p_obj_hp / 4] - 5 * p_player_at]		;ADC #[$0A + $01 * [$02 - $00 / $04] - $05 * $04]
NOP																;NOP

; Remove all of the following lines
p_obj = $5150													
p_obj_hp = 0
p_obj_mp = 2
p_obj_at = 4

p_player = $5000
p_player_at = 4