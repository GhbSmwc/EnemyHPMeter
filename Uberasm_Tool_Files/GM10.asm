;Gamemode 10 (Fade to level - blackness)

	incsrc "../EnemyHPDefines/EnemyHP.asm"
	incsrc "../EnemyHPDefines/GraphicalBarDefines.asm"

init:
	LDA #$FF				;\Prevent leaving the level and entering back
	STA !Freeram_SprHPCurrSlot		;/with the health bar still present.
	RTL