;Use this for gamemode 14 of uberasm tool.

	incsrc "../EnemyHPDefines/EnemyHP.asm"
	incsrc "../EnemyHPDefines/GraphicalBarDefines.asm"

init:
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;This makes smw bosses have intro HP. Big boo boss MUST be
	;in the screen the player spawn to start the intro HP.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	if !ShowHPOnSmwBosses != 0
		.InitalBossHP
		..LookForBossSlot
		LDX.b #!sprite_slots-1

		...Loop
		LDA !14C8,x		;\If sprite non-existent, next
		BEQ ....Next		;/
		LDA !Ram_CustSprBit,x	;\If it is a custom sprite, next
		AND #$08		;|
		BNE ....Next		;/
		LDA !9E,x		;>Smw's sprite number...
		CMP #$C5		;\Big boo
		BEQ ..SelectedBoss	;/
		CMP #$29		;\koopa kid (Don't use other than Morton, Lemmy, Ludwig, Wendy, and/or Roy)
		BEQ ..SelectedBoss	;/

		....Next
		DEX
		BPL ...Loop
		BRA ..Done

		..SelectedBoss
		TXA					;\Set current slot
		STA !Freeram_SprHPCurrSlot		;/
		if !Setting_SpriteHP_BarAnimation != 0
			LDA #$00				;\Make health bar start empty and fills up
			STA !Freeram_SprTbl_RecordEfft,x	;/
		endif
		..Done
	endif
	RTL
main:
	JSL !DummyJSL_EnemyHP_DisplayHP			;>code for enemies besides bosses.
	RTL