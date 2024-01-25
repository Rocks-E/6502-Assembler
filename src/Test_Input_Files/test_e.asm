; Test file e
; Check that constants can contain expressions

; Standard $1000
p_obj_player = $1000
; Expression add
p_obj_player_hp = [p_obj_player + 4]
; Expression without brackets
p_obj_player_mp = p_obj_player_hp + 2
; Expression with multiple symbols
p_obj_enemy = p_obj_player * 2 + p_obj_player_hp
; Expression with symbol that has not been named 
p_obj_enemy_malformed = p_obj_enemy + m_obj_player_hp

m_obj_player_hp = $15

LDA p_obj_player
LDA p_obj_player_hp
LDA p_obj_player_mp
LDA p_obj_enemy
LDA p_obj_enemy_malformed

.org p_obj_player_hp
.word m_obj_player_hp