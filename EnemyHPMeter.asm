;Note: Some routines here can be reused for non-enemy HP related code,
;therefore, you can move these codes to a "Shared Subroutines" patch
;to save space.
;
;Routines you likely to re-use (CTRL+F to find them):
;-CalculateGraphicalBarPercentage ;\graphical bar-related stuff
;-DrawGraphicalBar                ;/
;-MathMul32_32                    ;>32-bit*32-bit = 64-bits multiplication routine
;-MathDiv                         ;>16-bit/16-bit division routine
;-MathDiv32_16                    ;>32-bit/16-bit division routine (great for calculate percentage)
;-MathMul16_16                    ;>16-bit*16-bit = 32-bit multiplication (2 of them due to SA-1)
;-ConvertFillToTileNumb           ;>convert fill/byte (or tile) amount to tile number
;-ConvertToDigits                 ;>convert hex to decimal; handles 5 digits.
;-RemoveLeadingZeros              ;>Used with above to remove leading zeros.
;-LeftAlignedDigit                ;>same as removing leading zeroes, but also omits leading spaces.
;
;Note that they may be disabled (example: LeftAlignedDigit) due to not being needed when the user
;disallow things, example: alignment of digits of "Setting_EnemyHPAlignDigits".
;
;Another note is "duplicates" such as two multiplication and division routines, this is because
;some routines such as the graphical bar reserve certain temporally data stored in scratch RAM
;($00-$0F), obviously they hog up different amount of bytes, and some codes need to preserve a
;value.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This patch merely makes sprites use the HP system. Use JSL $xxxxxx
;in uberasm to run code that shows HP.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	incsrc "EnemyHPDefines/Sa1_Detect.asm"
	incsrc "EnemyHPDefines/SA1_SpriteDefines.asm"

	incsrc "EnemyHPDefines/EnemyHP.asm"
	incsrc "EnemyHPDefines/GraphicalBarDefines.asm"

;Do note that the 5 fireballs thing will not show HP. You'll have to code them yourself
;(see sprite hitbox test for reference).

;^These defines are better here in this ASM rather than inside the subfolder's
;code to reduce the chance of define conflicts.

;Defines you probably don't want to touch:
 !DigitTable = $02 ;for the 4-5 hex-dec conversion routine.
 if !sa1 != 0
  !DigitTable = $04
 endif
 
 !EnemyHPMaxUnsignIntegerMaxDigit = 3 ;>max unsigned 8-bit integer: 255
 if !Setting_SpriteHP_TwoByteHP != 0
  !EnemyHPMaxUnsignIntegerMaxDigit = 5 ;>max unsigned 16-bit integer: 65535
 endif

!NumberOfCharactersForMaxHP = 0
if !Setting_SpriteHP_DisplayNumerical == 2
	!NumberOfCharactersForMaxHP = !Setting_EnemyHPMaxDigits+1 ;>the second number (displays max HP) plus 1 due to a "/"  symbol.
endif
!EnemyHPMaxCharacterSize = !Setting_EnemyHPMaxDigits+!NumberOfCharactersForMaxHP ;> <CurrHP>/<maxHP>. where "/<maxHP>" can be removed.

!RightAlignedSingleNumber = 0
if !Setting_EnemyHPAlignDigits == 2 && !Setting_SpriteHP_DisplayNumerical != 0 ;>because of a stupid glitch asar had where [if 1 == 1 || (2 == 2 && 1 == 1)] complains mismatch parenthesis.
	!RightAlignedSingleNumber = 1
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Normal sprite table <-> SA-1 sprite table
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print "" ;>This is a linebreak
print "What sprite slot should the meter display.........$", hex(!Freeram_SprHPCurrSlot)
print ""
print "Sprite table size: $", hex(!sprite_slots), ", (", dec(!sprite_slots), " in decimal)"
print "Sprite's current HP (low byte)....................$", hex(!Freeram_SprTbl_CurrHPLow), " to $", hex(!Freeram_SprTbl_CurrHPLow+(!sprite_slots-1))
if !Setting_SpriteHP_TwoByteHP != 0
	print "Sprite's current HP (high byte)...................$", hex(!Freeram_SprTbl_CurrHPHi), " to $", hex(!Freeram_SprTbl_CurrHPLow+(!sprite_slots-1))
endif
print "Sprite's max HP (low byte)........................$", hex(!Freeram_SprTbl_MaxHPLow), " to $", hex(!Freeram_SprTbl_CurrHPLow+(!sprite_slots-1))
if !Setting_SpriteHP_TwoByteHP != 0
	print "Sprite's max HP (high byte).......................$", hex(!Freeram_SprTbl_MaxHPHi), " to $", hex(!Freeram_SprTbl_CurrHPLow+(!sprite_slots-1))
endif
if !Setting_SpriteHP_BarAnimation != 0
	print "Bar record effect (damage indicator)..............$", hex(!Freeram_SprTbl_RecordEfft), " to $", hex(!Freeram_SprTbl_CurrHPLow+(!sprite_slots-1))
	if !EnemyHPBarRecordDelay != 0
		print "Bar record effect freeze (timer before shrinking).$", hex(!Freeram_SprTbl_RecordEffTmr), " to $", hex(!Freeram_SprTbl_CurrHPLow+(!sprite_slots-1))
	endif
endif
print ""
;;;;;;;;;;;;;;;;;;
;Chuck hijacks
;;;;;;;;;;;;;;;;;;

	if !ShowHPOnChuck != 0
		org $02C7E8
		autoclean JSL DamageCharginChuck	;>Initial damage (stomp)
		NOP #2
	else
		if read1($02C7E8) == $22
			autoclean read3($02C7E8+1)
		endif
		org $02C7E8
		INC.W !1528,X
		LDA.W !1528,X
	endif
	if !ShowHPOnChuck != 0
		org $02C7EF
		db !AllChucksFullHP			;>Amount of HP to kill for chucks
	else
		org $02C7EF
		db 3
	endif

	if !ShowHPOnChuck != 0
		org $02C1F8
		autoclean JML CharginChuckHitCountToHP	;>Had to be JML instead JSL because you cannot PHA : RTL [...] PLA.
	else
		if read1($02C1F8) == $5C			;>if there is a hijacked code...
			autoclean read3($02C1F8+1)		;>...then remove freespace code first
		endif
		org $02C1F8
		LDA.W !187B,X					;\Restore overwritten code
		PHA						;/
	endif

	if !ShowHPOnChuck != 0
		org $02C20C
		autoclean JSL PreventHPMeterTransferChuck
		NOP
	else
		if read1($02C20C) == $22			;>if there is a hijack...
			autoclean read3($02C20C+1)		;>...then remove freespace code first
		endif
		org $02C20C
		LDA #$28					;\Restore overwritten code
		STA.W !163E,X					;/
	endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;5 fireballs kill hijack
;This will make smw not use the old "Takes 5 fireballs to
;kill" code. Do note that this applies to ALL normal sprites
;(including custom) that uses 5 fireballs HP if you modify
;using tweaker/CFG editor. This is to make the chuck
;compatible with fireball damage. Not compatible with Bio's
;"FireBall HP" patch.
;
;Due to being mangled with chargin chuck, this must be disabled
;if you don't want a HP bar displayed on chucks.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	if !ShowHPOnChuck != 0
		org $02A0FC
		autoclean JSL FiveFireAtDeath
		NOP #2
	else
		if read1($02A0FC) == $22
			autoclean read3($02A0FC+1)
		endif
		org $02A0FC
		INC.W !1528,X
		LDA.W !1528,X
	endif

	if !ShowHPOnChuck != 0
		org $02A103
		db #!AllChucksFullHP
	else
		org $02A103
		db 5
	endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Big boo boss hijacks
;Note: In the original SMW, the Big Boo's HP ($1534,x) does
;not get updated at the moment getting hit, but gets
;updated AFTER it changes state. I've modify so that the HP
;actually changes during hit to prevent "delayed damage"
;(HP shown does not decrease when attacking, rather after the
;end of the stunned pose) being shown.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	if !ShowHPOnSmwBosses != 0
		org $038233				;\When Big boo boss takes damage from
		autoclean JSL DamageBigBooBoss		;|a thrown sprite.
		NOP #1					;|
	else
		if read1($038233) == $22		;|
			autoclean read3($038233+1)	;|
		endif					;|
		org $038233				;|
		LDA #$28				;|
		STA $1DFC|!addr				;/
	endif


	org $03819B					;\Big Boo's hit counter actually increments
	if !ShowHPOnSmwBosses != 0			;|when switching state, not the instant the
		NOP #3					;|boo gits hit.
	else						;|
		INC.W !1534,X				;|
	endif						;/

	org $0381A2					;\Amount of hits to defeat big boo.
	if !ShowHPOnSmwBosses
		db !BigBooBossFullHP
	else
		db $03
	endif

	if !ShowHPOnSmwBosses != 0
		org $0380A2				;\Big boo's "HP" is actually a hit counter
		autoclean JML BigBooBossHitCountToHP	;|that increments (starts at 0) every hit.
	else
		if read1($0380A2) == $5C		;|This hijacks converts the value to HP,
			autoclean read3($0380A2+1)	;|and makes it display its health.
		endif					;|
		org $0380A2				;|
		CMP #$08				;|
		BNE $2E					;/
	endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Wendy and Lemmy hijacks ("PipeKoopaKids")
;This also have a delay damage as well (probably all SMW
;bosses that have "damage pose") to be edited.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	if !ShowHPOnSmwBosses != 0
		org $03CECB
		autoclean JSL DamageWendyLemmy
		NOP #1
	else
		if read1($03CECB) == $22
			autoclean read3($03CECB+1)
		endif
		org $03CECB
		LDA #$28
		STA $1DFC|!addr
	endif

	org $03CE13
	if !ShowHPOnSmwBosses != 0
		NOP #3					;>Remove delay damage
	else
		INC.W !1534,X
	endif
	
	org $03CE1A
	if !ShowHPOnSmwBosses
		db !WendyLemmyFullHP			;>Wendy/Lemmy's HP.
	else
		db $03
	endif
	
	org $03CED4
	if !ShowHPOnSmwBosses != 0
		db !WendyLemmyFullHP			;>Number of hits (no longer -1) to make sprites vanish
	else
		db $02
	endif

	if !ShowHPOnSmwBosses != 0
		org $03CC14
		autoclean JSL WendyLemmyHitCountToHP
		NOP #2
	else
		if read1($03CC14) == $22
			autoclean read3($03CC14+1)
		endif
		org $03CC14
		JSR.W $03D484
		LDA !14C8,X
	endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Ludwig, Morton, and Roy's HP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	if !ShowHPOnSmwBosses != 0
		org $01D3F3
		autoclean JSL FireballDamageLudwigMortonRoyHP	;>Fireball damage
		NOP #4 ;>This prevents incrementing hit counter past its maximum to prevent displaying negative HP
	else
		if read1($01D3F3) == $22
			autoclean read3($01D3F3+1)
		endif
		org $01D3F3
		LDA #$01
		STA $1DF9|!addr
		INC.W !1626,X
	endif

	org $01CFC6
	if !ShowHPOnSmwBosses != 0
		NOP #3						;>Remove delay damage (stomp)
	else
		INC.W !1626,X
	endif

	if !ShowHPOnSmwBosses != 0
		org $01CFCD
		db !LudwigMortonRoyFullHP			;>Set HP value

		org $01D3FF
		db !LudwigMortonRoyFullHP			;>Same as above, but fireball.
	else
		org $01CFCD
		db 3						;>Set HP value

		org $01D3FF
		db 12						;>Same as above, but fireball.
	endif
	if !ShowHPOnSmwBosses != 0
		org $01CDAB
		autoclean JSL LudwigMortonRoyHitCountToHP	;>Convert HP
		NOP #2
	else
		if read1($01CDAB) == $22
			autoclean read3($01CDAB+1)
		endif
		org $01CDAB
		STZ.W $13FB|!addr
		LDA.W !1602,X
	endif

	if !ShowHPOnSmwBosses != 0
		org $01D3AB
		autoclean JSL StompDamageLudwigMortonRoyHP	;>Stomp damage.
	else
		if read1($01D3AB) == $22
			autoclean read3($01D3AB+1)
		endif
		org $01D3AB
		LDA #$28
		STA $1DFC|!addr
	endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Dummy JML/JSL
;so that you don't have to worry about having to update your
;JSL addresses should you patch again.
;
;Remember, JML $123456 is [5C 56 34 12] in assembled hex form,
;which would take 4 bytes for each JML opcode.
;
;Feel free to move these (and its routines) to the shared
;subroutines patch. Don't forget to include the definitions
;files when doing so.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	org !Addr_DummyJSLs
	if !EnemyHP_RatsDisplacement == $08
		db "S","T","A","R"					;>[4 bytes] rats tag itself
		dw JMLListEnd-JMLListStart-1				;>[2 bytes] size-1
		dw ((JMLListEnd-JMLListStart)-1)^$FFFF			;>[2 bytes] XOR of above.
	endif
	JMLListStart:
	if !Setting_SpriteHP_BarAnimation != 0
		print "dummy JSL remove record effect................JSL $",pc
		autoclean JML RemoveRecordEffect
	endif

	print "dummy JSL lose HP.............................JSL $",pc
	autoclean JML LoseHP

	print "dummy JSL display HP..........................JSL $",pc
	autoclean JML WriteEnemyHP

	print "Dummy JSL get HP percentage...................JSL $",pc
	autoclean JML GetCurrentPercentHP
	
	JMLListEnd:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Freecode stuff
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
freecode
if !ShowHPOnChuck != 0
	;---------------------------------------------------------------------------------
	DamageCharginChuck: ;$02C7E8
	JSL SwitchHPBar

	.Restore
	LDA !1528,x			;\add damage count
	CLC				;|
	ADC #!AllChucksStompDmg		;/
	BCS .CapDamage			;>in case if you have the damage exceed 255
	CMP.b #!AllChucksFullHP
	BCC .Alive

	.CapDamage
	LDA.b #!AllChucksFullHP		;>Prevent damage count going too high

	.Alive
	STA !1528,x
	+
	RTL

	;---------------------------------------------------------------------------------
	;this code runs every frame, even when they're falling off the screen
	CharginChuckHitCountToHP: ;02C1F8
	LDA !14C8,x				;\don't write HP while dying.
	CMP #$08				;|
	BNE .Restore				;/

	.HPConvert
	LDA.b #!AllChucksFullHP			;\Set max HP
	STA !Freeram_SprTbl_MaxHPLow,x		;/
	SEC					;\RemainingHitsLeft = KillingValue - TotalDamageTaken
	SBC !1528,x				;/
	STA !Freeram_SprTbl_CurrHPLow,x		;>And display HP correctly
	if !Setting_SpriteHP_TwoByteHP != 0
		LDA #$00				;\Rid high bytes.
		STA !Freeram_SprTbl_CurrHPHi,x		;|
		STA !Freeram_SprTbl_MaxHPHi,x		;/
	endif
	if !Setting_SpriteHP_BarAnimation != 0
		.RemoveRecordWhenSwitchingHPs
		TXA					;>Don't worry, this copies X, not just transfer
		CMP !Freeram_SprHPCurrSlot		;>Compare with the slot the HP bar is using
		BEQ ..ItsOnThisSprite			;>If HP bar is on this current sprite, don't remove record
		JSL GetCurrentPercentHP			;\set record to HP %
		LDA $00					;|
		STA !Freeram_SprTbl_RecordEfft,x	;/
		BRA .Restore
		
		..ItsOnThisSprite
	endif


	.Restore
	LDA !187B,x
	PHA
	JML $02C1FC			;>Again, PHA : RTL : PLA crashes the game because RTL pulls stack.
	;---------------------------------------------------------------------------------
	PreventHPMeterTransferChuck:		;>$02C20C
	.Restore
	LDA #$28
	STA !163E,x
	
	.HideHPBar
	LDA !14C8,x			;\check individual sprites' slot death
	BNE +				;/
	LDA #$FF			;\Prevent HP bar from switching to a different enemy that spawn in the same slot
	STA !Freeram_SprHPCurrSlot	;/as this when this sprite dies in the same frame.
	+
	RTL

	;---------------------------------------------------------------------------------
	FiveFireAtDeath: ;02A0FC
	JSL SwitchHPBar
	
	LDA !1528,x
	CLC
	ADC.b #!AllChucksFireDmg	;>Fireball damage count
	BCS .CapDamage			;>in case if you have the damage exceed 255
	CMP.b #!AllChucksFullHP		;>damage count
	BCC .Alive			;>if damage smaller than max, leave it alive
	
	.CapDamage
	LDA.b #!AllChucksFullHP

	.Alive
	STA !1528,x
	RTL
endif
;---------------------------------------------------------------------------------
if !ShowHPOnSmwBosses != 0
		DamageBigBooBoss: ;038233
		JSL SwitchHPBar
		LDA !1534,x			;\increase damage count
		CLC				;|
		ADC.b #!BigBooBossThrSprDmg	;/
		BCS .CapDamage			;>in case if you have the damage exceed 255
		CMP.b #!BigBooBossFullHP	;\if added damage smaller, count as valid.
		BCC .ValidDamage		;/
		
		.CapDamage
		LDA.b #!BigBooBossFullHP	;>Cap the damage
		
		.ValidDamage
		STA !1534,x

		.Restore
		LDA #$28		;\hurt SFX
		STA $1DFC+!addr		;/
		RTL
		;---------------------------------------------------------------------------------
		BigBooBossHitCountToHP: ;0380A2
		;JSL !DummyJSL_EnemyHP_DisplayHP
		LDA.b #!BigBooBossFullHP	;\Set max HP
		STA !Freeram_SprTbl_MaxHPLow,x	;/
		SEC				;\RemainingHitsLeft = KillingValue - TotalDamageTaken
		SBC !1534,x			;/
		STA !Freeram_SprTbl_CurrHPLow,x	;>And display HP correctly
		if !Setting_SpriteHP_TwoByteHP != 0
			LDA #$00			;\Rid high bytes.
			STA !Freeram_SprTbl_CurrHPHi,x	;|
			STA !Freeram_SprTbl_MaxHPHi,x	;/
		endif

		.Restore
		LDA !14C8,x
		CMP #$08
		BNE ..Return0380D4

		JML $0380A6

		..Return0380D4
		JML $0380D4
		;---------------------------------------------------------------------------------
		DamageWendyLemmy: ;03CECB
		JSL SwitchHPBar
		LDA !1534,x			;\Increase damage count
		CLC				;|
		ADC.b #!WendyLemmyStompDmg	;/
		BCS .CapDamage
		CMP.b #!WendyLemmyFullHP	;\check if damage is over its max
		BCC .ValidDamage		;/
		
		.CapDamage
		LDA.b #!WendyLemmyFullHP

		.ValidDamage
		STA !1534,x

		.Restore
		LDA #$28
		STA $1DFC+!addr
		RTL
		;---------------------------------------------------------------------------------
		WendyLemmyHitCountToHP: ;03CC14
		;JSL !DummyJSL_EnemyHP_DisplayHP
		LDA.b #!WendyLemmyFullHP	;\Set max HP
		STA !Freeram_SprTbl_MaxHPLow,x	;/
		SEC				;\RemainingHitsLeft = KillingValue - TotalDamageTaken
		SBC !1534,x			;/
		STA !Freeram_SprTbl_CurrHPLow,x	;>And display HP correctly
		if !Setting_SpriteHP_TwoByteHP != 0
			LDA #$00			;\Rid high bytes.
			STA !Freeram_SprTbl_CurrHPHi,x	;|
			STA !Freeram_SprTbl_MaxHPHi,x	;/
		endif

		.Restore
		PHK				;\JSL-RTS trick.
		PER $0006
		PEA $827E
		JML $03D484

		LDA !14C8,x
		RTL
		;---------------------------------------------------------------------------------
		FireballDamageLudwigMortonRoyHP: ;01D3F3
		;Thankfully, there is no delay damage for fireball damage, since the developers
		;programmed damage that makes the boss "flinch" or "stun" would apply damage AFTER
		;the boss "un-stun" itself.

		JSL SwitchHPBar

		.Restore
		LDA #$28			;\SFX
		STA $1DFC+!addr			;/
		LDA !1626,x
		CLC
		ADC.b #!LudwigMortonRoyFireDmg
		BCS ..CapDamage			;>in case if you have the damage exceed 255
		CMP.b #!LudwigMortonRoyFullHP
		BCC ..ValidDamage
		
		..CapDamage
		LDA.b #!LudwigMortonRoyFullHP
		
		..ValidDamage
		STA !1626,x
		RTL
		;---------------------------------------------------------------------------------
		StompDamageLudwigMortonRoyHP: ;01D3AB
		JSL SwitchHPBar

		LDA !1626,x
		CLC
		ADC.b #!LudwigMortonRoyStompDmg
		BCS .CapDamage			;>in case if you have the damage exceed 255
		CMP.b #!LudwigMortonRoyFullHP
		BCC .EnoughHP
		
		.CapDamage
		LDA.b #!LudwigMortonRoyFullHP

		.EnoughHP
		STA !1626,x

		.Restore:
		LDA #$28
		STA $1DFC+!addr
		RTL
		;---------------------------------------------------------------------------------
		LudwigMortonRoyHitCountToHP: ;01CDAB
		LDA.b #!LudwigMortonRoyFullHP		;\Set max HP
		STA !Freeram_SprTbl_MaxHPLow,x	;/
		SEC				;\RemainingHitsLeft = KillingValue - TotalDamageTaken
		SBC !1626,x		;/
		STA !Freeram_SprTbl_CurrHPLow,x	;>And display HP correctly
		if !Setting_SpriteHP_TwoByteHP != 0
			LDA #$00			;\Rid high bytes.
			STA !Freeram_SprTbl_CurrHPHi,x	;|
			STA !Freeram_SprTbl_MaxHPHi,x	;/
		endif

		.Restore
		STZ $13FB+!addr
		LDA !1602,x
		RTL
		;---------------------------------------------------------------------------------
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Switch HP bar
;When a sprite takes damage (excluding kills), causes the
;meter to appear or switch to the sprite that takes damage.
;Note that this also freezes damage indicator to show
;damage as it appears.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SwitchHPBar:
	TXA				;\Set what sprite slot the meter to show
	STA !Freeram_SprHPCurrSlot	;/
	if !EnemyHPBarRecordDelay != 0 && !Setting_SpriteHP_BarAnimation != 0
		LDA.b #!EnemyHPBarRecordDelay			;\Each hit freezes the damage indicator
		STA !Freeram_SprTbl_RecordEffTmr,x	;/
	endif
	RTL
	print "" ;>linebreak
	if !Setting_SpriteHP_BarAnimation != 0
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;Remove record effect when current sprite isn't selected
		;
		;This must run every frame to ensure that the record effect
		;does not hang during its current HP bar not showing.
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		print "SubrAddr_RemoveRecordEffect...................JSL $", pc, " <- use this for custom sprites (every frame)"
		RemoveRecordEffect:
			TXA				;\Compare sprite slot to what
			CMP !Freeram_SprHPCurrSlot	;/slot the HP bar is on
			BEQ .Skip
			JSL GetCurrentPercentHP			;\set record effect to current HP percentage.
			LDA $00					;|
			STA !Freeram_SprTbl_RecordEfft,x	;/

			.Skip
			RTL
	endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Damage sprite subroutine.
;Input:
;*$00 to $00+!Setting_SpriteHP_TwoByteHP = Amount of damage.
;Output:
;*HP is already subtracted, if damage > currentHP, HP is
; set to 0.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoseHP:
	JSL SwitchHPBar
	if !Setting_SpriteHP_BarAnimation != 0 && !EnemyHPBarRecordDelay != 0
		LDA.b #!EnemyHPBarRecordDelay		;\Freeze damage indicator
		STA !Freeram_SprTbl_RecordEffTmr,x	;/
	endif
	if !Setting_SpriteHP_TwoByteHP != 0
		LDA !Freeram_SprTbl_CurrHPHi,x		;>HP high byte
		XBA					;>Transfer to A's high byte
		LDA !Freeram_SprTbl_CurrHPLow,x		;>HP low byte in A's low byte
		REP #$20				;>Make A read also the high byte.
		SEC					;\Subtract by damage.
		SBC $00					;/
		SEP #$20				;>8-bit A (low byte)
		BCS .NonNegHP				;>if HP value didn't underflow, set HP to subtracted value.
		LDA #$00				;\Set HP to 0
		STA !Freeram_SprTbl_CurrHPLow,x		;|
		STA !Freeram_SprTbl_CurrHPHi,x		;/
		RTL

		.NonNegHP
		STA !Freeram_SprTbl_CurrHPLow,x		;>Low byte subtracted HP
		XBA					;>Switch to high byte
		STA !Freeram_SprTbl_CurrHPHi,x		;>High byte subtracted HP
	else
		LDA !Freeram_SprTbl_CurrHPLow,x		;\if HP subtracted by damage didn't underflow (carry set), write HP
		SEC					;|
		SBC $00					;|
		BCS .NonNegHP				;/
		LDA #$00				;>otherwise if underflow (carry clear; borrow needed), set HP to 0.
		
		.NonNegHP
		STA !Freeram_SprTbl_CurrHPLow,x
	endif
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Uberasm tool major subroutine code.
;
;This writes stuff on the status bar/heads-up display.
;
;The reason why I put this here (and have uberasm tool JSL to here) is because:
;
; -the sprites from smw is in this patch, while sprite tool sprite defines cannot
; go here.
;
; -It is a mess that you have some of the incsrc information from uberasm itself
; and here as well. I am trying to reduce the number files using incsrc as
; possible. Even worse, romi's spritetool does not properly handle
; [print "text here won't work due to a dumb bug with init and main labels", pc]
; of the console command window.
;
;Also feel free to move my graphical bar routine
;(CalculateGraphicalBarPercentage and DrawGraphicalBar) to shared subroutines
;(does the JSL...JML...RTL the same way as my dummy JSL thingy)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;-------------------------------------------------------------------------------
WriteEnemyHP:
.RecordFreezeTimer
	if !Setting_SpriteHP_BarAnimation != 0
		if !EnemyHPBarRecordDelay != 0
			LDX.b #!sprite_slots-1			;>Load sprite slot countdown

			..Loop
			...RecordFreezeTimer
			LDA !Freeram_SprTbl_RecordEffTmr,x	;
			BEQ ...NextSlot				;>If timer already zero, don't decrement
			DEC A					;\Decrease timer.
			STA !Freeram_SprTbl_RecordEffTmr,x	;/

			...NextSlot
			DEX					;>Next slot
			BPL ..Loop				;>Loop if there are valid slots left
		endif

		.StartRecordFullSprInit
		LDX.b #!sprite_slots-1

		..SlotLoop
		LDA !14C8,x							;\If sprite is initial...
		CMP #$01							;/
		BNE ...Next
		LDA.b #(!Default_MiddlePieces*!Default_MiddleLength)+!Default_LeftPieces+!Default_RightPieces	;\Start with bar showing
		STA !Freeram_SprTbl_RecordEfft,x								;/full (so after the first hit show its previous HP %)
		
		...Next
		DEX
		BPL ..SlotLoop
	endif

.WriteMeter
	LDA !Freeram_SprHPCurrSlot	;\Hide HP meter if no sprite selected
	CMP #$FF			;|
	BNE ..Skip0			;|>branch out of range (BOOR)
	JML .HideHPMeter		;/
	..Skip0
	TAX				;>Transfer selected sprite to X

	LDA !14C8,x			;\If current sprite non-exist, set the selector to not select anything
	BNE ..Skip1			;>BOOR
	JML .SelectNoSpr 		;/

	..Skip1 ;while $14C8,x is an existent slot
	CMP #$01
	BEQ ..Skip2
	CMP #$02					;\#$02 = falling off screen
	BEQ ..ZeroHP					;/
	CMP #$04					;\#$04-#$07 spinjump, lava, level end killed
	BCC ..Skip2					;|
	CMP.b #$07+1					;|
	BCC ..ZeroHP					;/
	BRA ..Skip2					;>#$08+ alive

	..ZeroHP
	if !Setting_SpriteHP_BarAnimation != 0
		LDA !Freeram_SprTbl_CurrHPLow,x			;\when instant-killed, only set the record effect timer
		if !Setting_SpriteHP_TwoByteHP != 0
			ORA !Freeram_SprTbl_CurrHPHi,x			;|only once.
		endif
		BEQ ..Skip2					;/
	endif
	LDA #$00					;\Display 0HP when instant killed.
	STA !Freeram_SprTbl_CurrHPLow,x			;|
	if !Setting_SpriteHP_TwoByteHP != 0
		STA !Freeram_SprTbl_CurrHPHi,x			;/
	endif
	if !Setting_SpriteHP_BarAnimation && !SpriteHPRecordDelayExist != 0
		LDA.b #!EnemyHPBarRecordDelay			;\record effect timer
		STA !Freeram_SprTbl_RecordEffTmr,x		;/
	endif

	..Skip2
	LDA #!Default_LeftPieces			;\Set bar settings.
	STA !Scratchram_GraphicalBar_LeftEndPiece	;|
	LDA #!Default_MiddlePieces			;|
	STA !Scratchram_GraphicalBar_MiddlePiece	;|
	LDA #!Default_RightPieces			;|
	STA !Scratchram_GraphicalBar_RightEndPiece	;|
	LDA #!Default_MiddleLength			;|
	STA !Scratchram_GraphicalBar_TempLength		;/
	JSL GetCurrentPercentHP				;>get health percentage

	;$00 = sprite's current HP %
	if !Setting_SpriteHP_BarAnimation != 0
		.RecordOverwrite
		LDA $00					;>currant's percentage
		CMP !Freeram_SprTbl_RecordEfft,x	;>currant's record
		BEQ .GotoWriteBar			;>If CurrentPercent = RecordPercent, simply don't overwrite
		BCC ..Damage				;>CurrentPercent < RecordPercent (RecordPercent bigger, decrease record)

		..Heal
		;This is used as an intro when the health bar appears.
		if !EnemyHPBarSfxNumb != 0
			...Sfx
			LDA $13					;\\Certain frames play sfx
			AND.b #%00000001			;|/
			ORA $13D4+!addr				;|>Pause = no sfx.
			BNE ....NoSfx				;/
			LDA #!EnemyHPBarSfxNumb			;\If modulo result is exact 0, play SFX.
			STA !EnemyHPBarSfxRamPort+!addr		;/

			....NoSfx
		endif
		if !EnemyHPBarFillUpSpd != 0 && !EnemyHPBarFillUpSpdPerFrame < 2
			LDA $13					;\Frames
			AND.b #!EnemyHPBarFillUpSpd		;/
			BNE ...OverwriteFill			;>On certain frames, don't increase fill (makes it fill slower)
		endif
		LDA !Freeram_SprTbl_RecordEfft,x	;\"Filling up" animation
		if !EnemyHPBarFillUpSpdPerFrame >= 2
			CLC						;\increment by 2+ per frame
			ADC.b #!EnemyHPBarFillUpSpdPerFrame		;/
			BCS ...GoesPast					;>If overflow (goes past 255), set record to HP %
			CMP $00						;\check if it didn't goes past the HP %
			BCC ...Increment				;/

			...GoesPast
			LDA $00						;\if did go past, set record to HP %
			STA !Freeram_SprTbl_RecordEfft,x		;/
			BRA .GotoWriteBar
			
			...Increment
			STA !Freeram_SprTbl_RecordEfft,x
		else
			INC					;\increment by 1
			STA !Freeram_SprTbl_RecordEfft,x	;/
			STA $00					;>And apply the filling to replace CurrentPercent
		endif

		...OverwriteFill
		LDA !Freeram_SprTbl_RecordEfft,x	;\Show only filling up bar when branch taken.
		STA $00					;/
		BRA .GotoWriteBar

		..Damage
		if !EnemyHPBarFillDrainSpd != 0 && !EnemyHPBarEmptyingSpdPerFrame < 2
			LDA $13
			AND.b #!EnemyHPBarFillDrainSpd		;>Certain frames don't shrink transparent effect
			if !EnemyHPBarRecordDelay != 0
				ORA !Freeram_SprTbl_RecordEffTmr,x	;>Don't decrement while timer running
			endif
			BNE ...TransperentAnimation			;>If certain frames OR timer set, don't decrement.
		else
			if !EnemyHPBarRecordDelay != 0
				LDA !Freeram_SprTbl_RecordEffTmr,x
				BNE ...TransperentAnimation		;>If certain frames OR timer set, don't decrement.
			endif
		endif
		if !EnemyHPBarEmptyingSpdPerFrame >= 2
			LDA !Freeram_SprTbl_RecordEfft,x
			SEC
			SBC.b #!EnemyHPBarEmptyingSpdPerFrame
			BCC ...Underflow			;>prevent decrementing past 0 and assuming there are 255 amount of fill.
			CMP $00
			BCS ...Decrement
			
			...Underflow
			LDA $00
			STA !Freeram_SprTbl_RecordEfft,x
			BRA .GotoWriteBar
			
			...Decrement
			STA !Freeram_SprTbl_RecordEfft,x
			BRA ...TransperentAnimation
		else
			LDA !Freeram_SprTbl_RecordEfft,x	;\Shrink record effect
			DEC					;|
			STA !Freeram_SprTbl_RecordEfft,x	;/
		endif
		...TransperentAnimation
		if !Setting_SpriteHP_ShowTransperent != 0
			LDA $13					;\Flicker every frame (transparent)
			AND.b #%00000001			;/
			BNE .GotoWriteBar			;>Flicker effect, every even frame rewrites the RecordFill.
		endif
		LDA !Freeram_SprTbl_RecordEfft,x	;>Overwrite fill with record amount on certain frames.
		STA $00					;/
	endif
	.GotoWriteBar
	JSL DrawGraphicalBar			;>convert the fill amount to fill in each bytes.
	JSL ConvertFillToTileNumb		;>convert each byte to tile number for display

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Write to status bar
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.TransferBarTileNumberToHud:
	if !StatusBarFormat == $01
		if !Leftwards == 0
			LDX.b #!GraphiBar_LeftTileExist+(!Default_MiddleLength*!GraphiBar_MiddleTileExist)+!GraphiBar_RightTileExist-1	;>Start loop counter

			.Loop
			LDA !Scratchram_GraphicalBar_FillByteTbl,x	;\Store tile data into status bar tiles
			STA !EnemyHPGraphicalBarPos,x			;/
			DEX						;>Next tile
			BPL .Loop					;>And loop
		else
			LDX.b #!GraphiBar_LeftTileExist+(!Default_MiddleLength*!GraphiBar_MiddleTileExist)+!GraphiBar_RightTileExist-1	;\Start loop
			LDY #$00						;/

			.Loop
			LDA !Scratchram_GraphicalBar_FillByteTbl,x		;\Transfer scratch to status bar
			STA !EnemyHPGraphicalBarPos,y				;/
			LDA.b #%01000000					;\Tile properties, use +$40 for minimalist status bars, $80 for SMB3. Note that leftwards does
			STA !EnemyHPGraphicalBarPos+$80,y			;/not work on smw's status bar (or future HUD patches that doesn't support tile properties stored in RAM.
			INY							;\Next tile
			DEX							;/
			BPL .Loop						;>And loop
		endif
	else
		if !Leftwards == 0
			LDX.b #((!GraphiBar_LeftTileExist+(!Default_MiddleLength*!GraphiBar_MiddleTileExist)+!GraphiBar_RightTileExist)*2)-2	;>Each 8x8 of SSB has 2 bytes
			LDY.b #(!GraphiBar_LeftTileExist+(!Default_MiddleLength*!GraphiBar_MiddleTileExist)+!GraphiBar_RightTileExist)-1	;>Each 8x8 of scratch is 1 byte each.

			.Loop
			PHX						;>Save SSB index
			TYX						;\LDA $xxxxxx,y does not exist
			LDA !Scratchram_GraphicalBar_FillByteTbl,x	;/
			PLX						;>Restore SSB index
			STA !EnemyHPGraphicalBarPos,x				;>Transfer to status bar tiles
			DEY							;\Next tile
			DEX							;|
			DEX							;/
			BPL .Loop						;>and loop
		else
			LDX.b #((!GraphiBar_LeftTileExist+(!Default_MiddleLength*!GraphiBar_MiddleTileExist)+!GraphiBar_RightTileExist)*2)-2	;>Status bar index
			LDY.b #$00							;>Scratch index

			.Loop
			PHX						;\Transfer to status bar tiles
			TYX						;|
			LDA !Scratchram_GraphicalBar_FillByteTbl,x	;|
			PLX						;|
			STA !EnemyHPGraphicalBarPos,x			;/
			INY						;\Next tile
			DEX						;|
			DEX						;/
			BPL .Loop					;>And loop

			.TileProperties
			LDX.b #((!GraphiBar_LeftTileExist+(!Default_MiddleLength*!GraphiBar_MiddleTileExist)+!GraphiBar_RightTileExist)*2)-1

			..Loop
			LDA #%01111000			;\Set tile properties (bit 6 must be set to apply the x flip)
			STA !EnemyHPGraphicalBarPos,x	;/
			DEX				;\Next tile (two DEYs since each each 8x8 tile holds 2 bytes:
			DEX				;/TTTTTTTT YXPPCCCT (little endian)
			BPL ..Loop			;>And loop
		endif
	endif

	if !Setting_SpriteHP_DisplayNumerical != 0
		.DrawNumerical
		if !Setting_EnemyHPAlignDigits == 0 || and(equal(!Setting_EnemyHPAlignDigits, 2), equal(!Setting_SpriteHP_DisplayNumerical, 1)) != 0
		;^numbers by default are right-aligned, the right-aligned code is only needed if you display 2 numbers (currentHP/MaxHP).

			LDA !Freeram_SprHPCurrSlot			;\X was overwritten by the previous loop.
			TAX						;/

			if and(less(!Setting_EnemyHPMaxDigits, !EnemyHPMaxUnsignIntegerMaxDigit), notequal(!Setting_EnemyHP_ExcessDigitProt, 0))
				JSL ExcessiveCharacterProtection
				BCC +
				;JMP .Done
				RTL
				+
			endif
			LDA !Freeram_SprTbl_CurrHPLow,x			;\begin converting current HP to digits.
			STA $00						;|
			if !Setting_SpriteHP_TwoByteHP != 0
				LDA !Freeram_SprTbl_CurrHPHi,x
				STA $01
			else
				STZ $01
			endif
			JSL ConvertToDigits				;>Translate each digit to a 0-9 characters (Binary coded-decimal)
			JSL RemoveLeadingZeros				;>Did not preserve x here, because X is still used below.

			..WriteCurrentHP				;\write current HP value to status bar.
			if !StatusBarFormat == 1
				LDX.b #!Setting_EnemyHPMaxDigits-1

				...Loop
				LDA.b (!DigitTable+(4-!Setting_EnemyHPMaxDigits))+1,x
				STA !EnemyHPNumericalPosition,x
				DEX
				BPL ...Loop
			else
				LDX.b #(!Setting_EnemyHPMaxDigits*2)-2				;>Loop index for tiles of 2 byte per 8x8
				LDY.b #!Setting_EnemyHPMaxDigits-1				;>Loop index for tiles of the scratch ram.

				...Loop
				LDA.w (!DigitTable+(4-!Setting_EnemyHPMaxDigits))+1+!dp,y	;>LDA $xx,y does not exist.
				STA !EnemyHPNumericalPosition,x
				DEX #2							;>Next super status bar tile
				DEY							;>Next scratch RAM
				BPL ...Loop
			endif
			if !Setting_SpriteHP_DisplayNumerical == 2
				...WriteMaximumHP
				LDA #!EnemyHPTilePrefixMax						;>Tile number of "/"
				STA !EnemyHPNumericalPosition+(!Setting_EnemyHPMaxDigits*!StatusBarFormat)	;>Write "/"

				LDA !Freeram_SprHPCurrSlot						;\X was overwritten by the previous loop.
				TAX									;/
				LDA !Freeram_SprTbl_MaxHPLow,x
				STA $00
				if !Setting_SpriteHP_TwoByteHP != 0
					LDA !Freeram_SprTbl_MaxHPHi,x
					STA $01
				else
					STZ $01
				endif
				JSL ConvertToDigits				;>Translate each digit to a 0-9 characters
				JSL RemoveLeadingZeros
				if !StatusBarFormat == 1
					LDX.b #!Setting_EnemyHPMaxDigits-1

					....Loop
					LDA.b (!DigitTable+(4-!Setting_EnemyHPMaxDigits))+1,x
					STA !EnemyHPNumericalPosition+!Setting_EnemyHPMaxDigits+1,x
					DEX
					BPL ....Loop
				else
					LDX.b #(!Setting_EnemyHPMaxDigits*2)-2				;>Loop index for tiles of 2 byte per 8x8
					LDY.b #!Setting_EnemyHPMaxDigits-1				;>Loop index for tiles of the scratch ram.

					....Loop
					LDA.w (!DigitTable+(4-!Setting_EnemyHPMaxDigits))+1+!dp,y	;>LDA $xx,y does not exist.
					STA !EnemyHPNumericalPosition+((!Setting_EnemyHPMaxDigits+1)*2),x
					DEX #2							;>Next super status bar tile
					DEY							;>Next scratch RAM
					BPL ....Loop
				endif
			endif
		elseif !Setting_EnemyHPAlignDigits == 1
			LDX.b #(!EnemyHPMaxCharacterSize*!StatusBarFormat)-!StatusBarFormat	;\Remove leftover garbage. #(X*!StatusBarFormat)-!StatusBarFormat where X...
			LDA #!EnemyHPBlankTile							;|>#$FC is the blank tile to replace garbage
			
			..Loop								;|...is the highest number of 8x8 tiles to be written.
			STA !EnemyHPNumericalPosition,x					;|
			DEX #!StatusBarFormat						;|
			BPL ..Loop							;/

			LDA !Freeram_SprHPCurrSlot		;\X was overwritten by the previous loop.
			TAX					;/
			if and(less(!Setting_EnemyHPMaxDigits, !EnemyHPMaxUnsignIntegerMaxDigit), notequal(!Setting_EnemyHP_ExcessDigitProt, 0))
				JSL ExcessiveCharacterProtection
				BCC +
				;JMP .Done
				RTL
				+
			endif
			LDA !Freeram_SprTbl_CurrHPLow,x		;\input current HP.
			STA $00					;|
			if !Setting_SpriteHP_TwoByteHP != 0
				LDA !Freeram_SprTbl_CurrHPHi,x
				STA $01
			else
				STZ $01
			endif
			JSL ConvertToDigits			;>convert value to decimal (more like BCD)
			LDX #$00				;>Input the index position of the string table
			JSL LeftAlignedDigit			;>Change the display (the current HP) to be left-aligned.
			if !Setting_SpriteHP_DisplayNumerical == 2
				LDA #!EnemyHPTilePrefixMax		;\"/" symbol
				STA !Scratchram_CharacterTileTable,x	;|
				INX					;/>move index over to write max HP after "/"
				PHX					;>Preserve character index
				LDA !Freeram_SprHPCurrSlot		;\switch index over to sprite slot.
				TAX					;/
				LDA !Freeram_SprTbl_MaxHPLow,x		;\input max HP
				STA $00					;|
				if !Setting_SpriteHP_TwoByteHP != 0
					LDA !Freeram_SprTbl_MaxHPHi,x
					STA $01
				else
					STZ $01
				endif
				PLX					;>restore character count.
				JSL ConvertToDigits
				JSL LeftAlignedDigit
			endif

			..StatusBarWrite
			if !StatusBarFormat == 1
				DEX					;>Start at the last tile and write towards the first
				
				...Loop
				LDA !Scratchram_CharacterTileTable,x
				STA !EnemyHPNumericalPosition,x
				DEX
				BPL ...Loop
			else
				TXY					;\Number of tiles to write (assuming you're using
				DEY					;|a tile map RAM formatted like this: TTTTTTTT YXPCCCTT
				TXA					;|
				ASL					;|Start at the last tile and write towards the first
				DEC #2					;|
				TAX					;/

				...Loop
				PHX					;\Write string to status bar.
				TYX					;|
				LDA !Scratchram_CharacterTileTable,x	;|
				PLX					;|
				STA !EnemyHPNumericalPosition,x		;|
				DEY					;|
				DEX #!StatusBarFormat			;|
				BPL ...Loop				;/
			endif
		elseif !Setting_EnemyHPAlignDigits == 2 && !Setting_SpriteHP_DisplayNumerical == 2
			;^Display only right-aligned CurrentHP/MaxHP.

			LDX.b #(!EnemyHPMaxCharacterSize*!StatusBarFormat)-!StatusBarFormat	;\Remove leftover garbage. #(X*!StatusBarFormat)-!StatusBarFormat where X...

			..Loop								;|...is the highest number of 8x8 tiles to be written.
			LDA #!EnemyHPBlankTile						;|>#$FC is the blank tile to replace garbage
			STA !EnemyHPNumericalPosition,x					;|
			DEX #!StatusBarFormat						;|
			BPL ..Loop							;/

			LDA !Freeram_SprHPCurrSlot		;\X was overwritten by the previous loop.
			TAX					;/

			if and(less(!Setting_EnemyHPMaxDigits, !EnemyHPMaxUnsignIntegerMaxDigit), notequal(!Setting_EnemyHP_ExcessDigitProt, 0))
				JSL ExcessiveCharacterProtection
				BCC +
				;JMP .Done
				RTL
				+
			endif
			LDA !Freeram_SprTbl_CurrHPLow,x		;\input current HP.
			STA $00					;|
			if !Setting_SpriteHP_TwoByteHP != 0
				LDA !Freeram_SprTbl_CurrHPHi,x
				STA $01
			else
				STZ $01
			endif
			JSL ConvertToDigits			;>convert value to decimal (more like BCD)
			LDX #$00				;>Input the index position of the string table
			JSL LeftAlignedDigit			;>Change the display (the current HP) to be left-aligned.
			if !Setting_SpriteHP_DisplayNumerical == 2
				LDA #!EnemyHPTilePrefixMax		;\"/" symbol
				STA !Scratchram_CharacterTileTable,x	;/
				INX					;>move index over to write max HP after "/"
				PHX					;>Preserve character index
				LDA !Freeram_SprHPCurrSlot		;\switch index over to sprite slot.
				TAX					;/
				LDA !Freeram_SprTbl_MaxHPLow,x		;\input max HP
				STA $00					;|
				if !Setting_SpriteHP_TwoByteHP != 0
					LDA !Freeram_SprTbl_MaxHPHi,x
					STA $01
				else
					STZ $01
				endif
				PLX					;>restore character count.
				JSL ConvertToDigits
				JSL LeftAlignedDigit
			endif
			;X = number of 8x8 to write (without -1).
			..ConvertToRightAligned
			LDA.b #!Scratchram_CharacterTileTable		;\Store address of the table
			STA $00						;|(<opcode>[$00],y means a "moveable table")
			LDA.b #!Scratchram_CharacterTileTable>>8	;|
			STA $01						;|
			LDA.b #!Scratchram_CharacterTileTable>>16	;|
			STA $02						;/
			DEX					;\Last character in $03 (also being the number of characters -1)
			STX $03					;/(if there are 3 digits (like 123, it would be 2, not 3))
			STZ $04					;>Remove high byte

			REP #$20
			LDA $00					;>Starting position of the RAM table
			CLC					;\Go all the way to the end of the table
			ADC.w #!EnemyHPMaxCharacterSize-1	;/
			SEC					;\Move the "moveable table" to the left so that
			SBC $03					;/the last character is the last of the table (rightmost without exceed)
			STA $00					;>Place "moveable table" starting here.
			SEP #$20

			PHX					;\Transfer string to the right section of the table
			TXY					;|

			..ShiftTable
			...Loop
			LDA !Scratchram_CharacterTileTable,x	;|
			STA [$00],y				;|
			DEY					;|
			DEX					;|
			BPL ...Loop				;|
			PLX					;/

			TXA					;\Index to use the right section of table for status bar
			CLC					;|
			ADC.b #!EnemyHPMaxCharacterSize-1	;|
			SEC					;|
			SBC $03					;|
			TAX					;/

			..StatusBarWrite
			if !StatusBarFormat == 1 ;\Write to status bar. $03 = number of 8x8s to write a string -1.
				...Loop
				LDA !Scratchram_CharacterTileTable,x
				STA !EnemyHPNumericalPosition,x
				DEX
				DEC $03
				BPL ...Loop
			else
				ASL
				TAY

				...Loop
				LDA !Scratchram_CharacterTileTable,x
				PHX
				TYX
				STA !EnemyHPNumericalPosition,x
				PLX
				DEY #2
				DEX
				DEC $03
				BPL ...Loop
			endif
		endif
	endif

	;JML .Done
	RTL

	.SelectNoSpr
	LDA #$FF					;\Make meter disappear
	STA !Freeram_SprHPCurrSlot			;/

	.HideHPMeter
	if !StatusBarFormat == 1
		..HideBar
		LDX.b #!Default_MiddleLength+!GraphiBar_LeftTileExist+!GraphiBar_RightTileExist-1	;>Total number 8x8 of tiles of bar -1.
		LDA #$FC										;>Blank tile

		...Loop
		STA !EnemyHPGraphicalBarPos,x						;>Write blank tile over the bar
		DEX							;\repeat until index is negative
		BPL ...Loop						;/
		if !Setting_SpriteHP_DisplayNumerical != 0
			..HideNumerical
			if !Setting_SpriteHP_DisplayNumerical == 1
				LDX.b #!Setting_EnemyHPMaxDigits-1		;>total number 8x8 of tiles of numbers -1.
			elseif !Setting_SpriteHP_DisplayNumerical == 2
				LDX.b #((!Setting_EnemyHPMaxDigits*2)+1)-1	;>total number 8x8 of tiles of numbers -1.
			endif
			...Loop
			STA !EnemyHPNumericalPosition,x			;>Write blank tile over the digits (and "/" if MaxHP displays)
			DEX
			BPL ...Loop
		endif
	else
		..HideBar
		LDX.b #((!Default_MiddleLength+!GraphiBar_LeftTileExist+!GraphiBar_RightTileExist)*2)-2
		LDA #!EnemyHPBlankTile

		...Loop
		STA !EnemyHPGraphicalBarPos,x
		DEX #2
		BPL ...Loop
		if !Setting_SpriteHP_DisplayNumerical != 0
			..HideNumerical
			if !Setting_SpriteHP_DisplayNumerical == 1
				LDX.b #(!Setting_EnemyHPMaxDigits*2)-2			;>total number 8x8 of tiles of numbers -2 (each tile holds two bytes).
			elseif !Setting_SpriteHP_DisplayNumerical == 2
				LDX.b #((!Setting_EnemyHPMaxDigits*2)+1)*2-2		;>total number 8x8 of tiles of numbers -2 (each tile holds two bytes).
			endif
			...Loop
			STA !EnemyHPNumericalPosition,x			;>Write blank tile over the digits (and "/" if MaxHP displays)
			DEX #2
			BPL ...Loop
		endif
	endif

	.Done
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Get current HP in percent
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GetCurrentPercentHP:
	if !Setting_SpriteHP_TwoByteHP != 0
		LDA !Freeram_SprTbl_CurrHPLow,x			;\current HP
		STA !Scratchram_GraphicalBar_FillByteTbl	;|
		LDA !Freeram_SprTbl_CurrHPHi,x			;|
		STA !Scratchram_GraphicalBar_FillByteTbl+1	;/
		LDA !Freeram_SprTbl_MaxHPLow,x			;\max HP
		STA !Scratchram_GraphicalBar_FillByteTbl+2	;|
		LDA !Freeram_SprTbl_MaxHPHi,x			;|
		STA !Scratchram_GraphicalBar_FillByteTbl+3	;/
	else
		LDA !Freeram_SprTbl_CurrHPLow,x			;\current HP
		STA !Scratchram_GraphicalBar_FillByteTbl	;/
		LDA !Freeram_SprTbl_MaxHPLow,x			;\max HP
		STA !Scratchram_GraphicalBar_FillByteTbl+2	;/
		LDA #$00					;\zero out high byte quantities
		STA !Scratchram_GraphicalBar_FillByteTbl+1	;|
		STA !Scratchram_GraphicalBar_FillByteTbl+3	;/
	endif
	LDA.b #!Default_MiddleLength			;\Set length of bar.
	STA !Scratchram_GraphicalBar_TempLength		;/
	LDA #!Default_LeftPieces			;\number of pieces in each 8x8 tile of the whole bar.
	STA !Scratchram_GraphicalBar_LeftEndPiece	;|
	LDA #!Default_MiddlePieces			;|
	STA !Scratchram_GraphicalBar_MiddlePiece	;|
	LDA #!Default_RightPieces			;|
	STA !Scratchram_GraphicalBar_RightEndPiece	;/
	PHX						;>Protect sprite slot
	JSL CalculateGraphicalBarPercentage		;>Get "CurrentPercent".
	PLX						;>Restore sprite slot
	if !Setting_EnemyHP_BarAvoidRoundToZero != 0
		CPY #$01
		BNE .NotRoundedToEmpty
		
		LDA #$01		;\round towards 1 pixel when near-empty.
		STA $00			;|
		STZ $01			;/
		
		.NotRoundedToEmpty
	endif
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Calculate ratio of Quantity/MaxQuantity to FilledPieces/TotalMaxPieces.
;
;Basically, this routine calculates the "percentage" amount of pieces
;filled. It does this formula in order for this to work (solve for
;"FilledPieces"):
;
; Cross multiply:
;
;   Quantity          FilledPieces
;   -----------   =   ------------
;   MaxQuantity       TotalMaxPieces
;
; Turns into:
;
; (Quantity * TotalMaxPieces)
; ---------------------------  = FilledPieces
;        MaxQuantity
;
;Where:
;*Quantity = the amount of something, say current HP.
;*MaxQuantity = the maximum amount of something, say max HP.
;*FilledPieces = the number of pieces filled in the whole bar (rounded 1/2 up).
; *Note that this value isn't capped (mainly Quantity > MaxQuantity), the
;  "DrawGraphicalBar" subroutine will detect and will not display over max,
;  just in case if you somehow want to use the over-the-max-value on advance
;  use (such as filling 2 seperate bars, filling up the 2nd one after the 1st
;  is full).
;*TotalMaxPieces = the number of pieces of the whole bar when full.
;
;Note that during a division, it checks if the remainder is greater than
;or equal to half of MaxQuantity (rounded 1/2 up) to check should it would
;round up or not (also rounds 1/2 up).
;
;Input:
; -!Scratchram_GraphicalBar_FillByteTbl to !Scratchram_GraphicalBar_FillByteTbl+1:
;  the quantity.
; -!Scratchram_GraphicalBar_FillByteTbl+2 to !Scratchram_GraphicalBar_FillByteTbl+3:
;  the max quantity.
; -!Scratchram_GraphicalBar_LeftEndPiece: number of pieces in left end
; -!Scratchram_GraphicalBar_MiddlePiece: same as above but for each middle
; -!Scratchram_GraphicalBar_RightEndPiece: same as above, but right end
; -!Scratchram_GraphicalBar_TempLength: number of middle bytes excluding both ends.
;
;Output:
; -$00 to $01: the "percentage" amount of fill in the bar (rounded 1/2 up).
; -Y register: if rounded towards empty (fill amount = 0) or full:
; --Y = #$00 if:
; ---Exactly full (or more, so it treats as if the bar is full if more than enough)
;    or exactly empty.
; ---Anywhere between full or empty
; --Y = #$01 if rounded to empty (so a nonzero value less than 0.5 pieces filled).
; --Y = #$02 if rounded to full (so if full amount is 62, values from 61.5 to 61.9).
;  This is useful in case you don't want the bar to display completely full or empty
;  when it is not.
;Overwritten/Destroyed:
; -$02 to $0F: because the 32x32bit multiplication routine ate the whole scratch RAM
;  data.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CalculateGraphicalBarPercentage:
.FindTotalPieces
..FindTotalMiddle
	if !Setting_GraphicalBar_SNESMathOnly == 0
		LDA !Scratchram_GraphicalBar_MiddlePiece	;\TotalMiddlePieces = MiddlePieces*MiddleLength
		STA $00						;|Note: Multiply two 8-bit numbers.
		STZ $01						;|
		LDA !Scratchram_GraphicalBar_TempLength		;|
		STA $02						;|
		STZ $03						;/
		JSL MathMul16_16				;MiddlePieceper8x8 * NumberOfMiddle8x8. Stored into $04-$07 (will read $04-$05 since number of pieces are 16bit, not 32)
	else
		LDA !Scratchram_GraphicalBar_MiddlePiece	;\TotalMiddlePieces = MiddlePieces*MiddleLength
		STA $4202					;|
		LDA !Scratchram_GraphicalBar_TempLength		;|
		STA $4203					;/
		XBA						;\Wait 8 cycles (XBA takes 3, NOP takes 2) for calculation
		XBA						;|
		NOP						;/
		LDA $4216					;\Store product.
		STA $04						;|
		LDA $4217					;|
		STA $05						;/
	endif
..FindTotalEnds ;>2 8-bit pieces added together, should result a 16-bit number not exceeding $01FE (if $200 or higher, can cause overflow since carry is only 0 or 1, highest highbyte increase is 1).
	STZ $01						;>Clear highbyte
	LDA !Scratchram_GraphicalBar_LeftEndPiece	;\Lowbyte total
	CLC						;|
	ADC !Scratchram_GraphicalBar_RightEndPiece	;|
	STA $00						;/
	LDA $01						;\Handle high byte (if an 8-bit low byte number exceeds #$FF, the high byte will be #$01.
	ADC #$00					;|$00-$01 should now hold the total fill pieces in the end bytes/8x8 tiles.
	STA $01						;/
..FindGrandTotal
	REP #$20
	LDA $04						;>Total middle pieces
	CLC
	ADC $00						;>Plus total end
.TotalPiecesTimesQuantity
	;STA $00						;>Store grand total in input A of 32x32bit multiplication
	;STZ $02						;>Rid the highword (#$0000XXXX)
	;LDA !Scratchram_GraphicalBar_FillByteTbl	;\Store quantity
	;STA $04						;/
	;STZ $06						;>Rid the highword (#$0000XXXX)
	;SEP #$20
	;JSL MathMul32_32				;>Multiply together. Results in $08-$0F (8 bytes; 64 bit).
	
	STA $00						;>Store 16-bit total pieces into multiplicand
	LDA !Scratchram_GraphicalBar_FillByteTbl	;\Store 16-bit quantity into multiplier
	STA $02						;/
	SEP #$20
	JSL MathMul16_16				;>Multiply together ($04-$07 (32-bit) is product)

	;Okay, the reason why I use the 32x32 bit multiplication is because
	;it is very easy to exceed the value of #$FFFF (65535) should you
	;have a number of pieces in the bar (long bar, or large number per
	;byte).
	
	;Also, you may see "duplicate" routines with the only difference is
	;that they are different number of bytes for the size of values to
	;handle, they are included and used because some of my code preserves
	;them and are not to be overwritten by those routines, so a smaller
	;version is needed, and plus, its faster to avoid using unnecessarily
	;large values when they normally can't reach that far.
	
	;And finally, I don't directly use SA-1's multiplication and division
	;registers outside of routines here, because they are signed. The
	;amount of fill are unsigned.

.DivideByMaxQuantity
	;REP #$20
	;LDA $08						;\Store result into dividend (32 bit only, its never to exceed #$FFFFFFFF), highest it can go is #$FFFE0001
	;STA $00						;|
	;LDA $0A						;|
	;STA $02						;/
	;LDA !Scratchram_GraphicalBar_FillByteTbl+2	;\Store MaxQuantity into divisor.
	;STA $04						;/
	;SEP #$20
	;JSL MathDiv32_16				;>;[$00-$03 : Quotient, $04-$05 : Remainder], After this division, its impossible to be over #$FFFF.

	REP #$20					;\Store result into dividend (32 bit only, its never to exceed #$FFFFFFFF), highest it can go is #$FFFE0001
	LDA $04						;|
	STA $00						;|
	LDA $06						;|
	STA $02						;/
	LDA !Scratchram_GraphicalBar_FillByteTbl+2	;\Store MaxQuantity into divisor.
	STA $04						;/
	SEP #$20
	JSL MathDiv32_16				;>;[$00-$03 : Quotient, $04-$05 : Remainder], After this division, its impossible to be over #$FFFF.
..Rounding
	REP #$20
	LDA !Scratchram_GraphicalBar_FillByteTbl+2	;>Max Quantity
	LSR						;>Divide by 2 (halfway point of max)..
	BCC ...ExactHalfPoint				;>Should a remainder in the carry is 0 (no remainder), don't round the 1/2 point
	INC						;>Round the 1/2 point

	...ExactHalfPoint
	CMP $04						;>Half of max compares with remainder
	BEQ ...RoundDivQuotient				;>If HalfPoint = Remainder, round upwards
	BCS ...NoRoundDivQuotient			;>If HalfPoint > remainder (or remainder is smaller), round down (if exactly full, this branch is taken).

	...RoundDivQuotient
	;^this also gets branched to if the value is already an exact integer number of pieces (so if the
	;quantity is 50 out of 100, and a bar of 62, it would be perfectly at 31 [(50*62)/100 = 31]
	LDA $00						;\Round up an integer
	INC						;/
	STA $08						;>move towards $08 because 16bit*16bit multiplication uses $00 to $07

	;check should this rounded value made a full bar when it is actually not:
	
	....RoundingUpTowardsFullCheck
	;Just as a side note, should the bar be EXACTLY full (so 62/62 and NOT 61.9/62, it guarantees
	;that the remainder is 0, so thus, no rounding is needed.) This is due to the fact that
	;[Quantity * FullAmount / MaxQuantity] when Quantity and MaxQuantity are the same number,
	;thus, canceling each other out (so 62 divide by 62 = 1) and left with FullAmount (the
	;number of pieces in the bar)
	
	;Get the full number of pieces
	if !Setting_GraphicalBar_SNESMathOnly == 0
		LDA !Scratchram_GraphicalBar_MiddlePiece	;\Get amount of pieces in middle
		AND #$00FF					;|
		STA $00						;|
		LDA !Scratchram_GraphicalBar_TempLength		;|
		AND #$00FF					;|
		STA $02						;/
		SEP #$20
		JSL MathMul16_16				;>[$04-$07: Product]
	else
		SEP #$20
		LDA !Scratchram_GraphicalBar_MiddlePiece
		STA $4202
		LDA !Scratchram_GraphicalBar_TempLength
		STA $4203
		XBA						;\Wait 8 cycles (XBA takes 3, NOP takes 2) for calculation
		XBA						;|
		NOP						;/
		LDA $4216					;\[$04-$07: Product]
		STA $04						;|
		LDA $4217					;|
		STA $05						;/
	endif
	LDY #$00					;>Default that the meter didn't round towards empty/full (cannot be before the above subroutine since it overwrites Y).

	;add the 2 ends tiles amount (both are 8-bit, but results 16-bit)
	
	;NOTE: should the fill amount be exactly full OR greater, Y will be #$00.
	;This is so that greater than full is 100% treated as exactly full.
	LDA #$00					;\A = $YYXX, (initially YY is $00)
	XBA						;/
	LDA !Scratchram_GraphicalBar_LeftEndPiece	;\get total pieces
	CLC						;|\carry is set should overflow happens (#$FF -> #$00)
	ADC !Scratchram_GraphicalBar_RightEndPiece	;//
	XBA						;>A = $XXYY
	ADC #$00					;>should that overflow happen, increase the A's upper byte (the YY) by 1 ($01XX)
	XBA						;>A = $YYXX, addition maximum shouldn't go higher than $01FE. A = 16-bit total ends pieces
	REP #$20
	CLC						;\plus middle pieces = full amount
	ADC $04						;/
	CMP $08						;>compare with rounded fill amount
	BNE .....TransferFillAmtBack			;\should the rounded up fill matches with the full value, flag that
	LDY #$02					;/it had rounded to full.

	.....TransferFillAmtBack
	LDA $08						;\move the fill amount back to $00.
	STA $00						;/
	BRA .Done
	
	...NoRoundDivQuotient
	....RoundingDownTowardsEmptyCheck
	LDY #$00					;>Default that the meter didn't round towards empty/full.
	LDA $00						;\if the rounded down (result from fraction part is less than .5) quotient value ISN't zero,
	BNE .Done					;/(exactly 1 piece filled or more) don't even consider setting Y to #$01.
	LDA $04						;\if BOTH rounded down quotient and the remainder are zero, the bar is TRUELY completely empty
	BEQ .Done					;/and don't set Y to #$01.
	
	LDY #$01					;>indicate that the value was rounded down towards empty
	
	.Done
	SEP #$20
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Convert amount of fill to each fill per byte.
;
;This basically breaks up the amount of fill in the whole bar into each
;bytes having their capacity.
;
;Notes:
; -This routine output only have 1 partially filled (non-full and non-empty)
;  byte, due to only 1 "fraction" is supported. To have custom edge, after
;  this routine is done, you simply read the amount of the fraction to
;  determine the edge is crossing the next 8x8 byte.
; -The fraction byte/8x8 tile includes the value 0 (it's actually 0 to max-1,
;  not 1 to max-1), thus if there are only full bytes tile and empty bytes after,
;  the first empty byte after the last full byte is considered the fraction tile.
;
;Input:
; -$00 to $01: The amount of fill for the WHOLE bar.
; -!Scratchram_GraphicalBar_LeftEndPiece: Number of pieces in left byte (0-255), also
;  the maximum amount of fill for this byte itself. If 0, it's not included in table.
; -!Scratchram_GraphicalBar_MiddlePiece: Same as above but each middle byte.
; -!Scratchram_GraphicalBar_RightEndPiece: Same as above but for right end.
; -!Scratchram_GraphicalBar_TempLength: The length of the bar (only counts
;   middle bytes)
;Output:
; -!Scratchram_GraphicalBar_FillByteTbl to !Scratchram_GraphicalBar_FillByteTbl+x:
;  A table containing the amount of fill for each byte. Calculated by taking
;  the total amount of fill in the whole bar and splits the value by filling
;  up each byte starting in byte 0 and advances to the next byte when
;  exceeding the byte's maximum. Once all the fill have been exhausted, the rest is
;  #$00.
;
;  Should the total amount of fill of the bar be greater than than the amount
;  needed to be full, the table act as if the bar is EXACTLY full (not exceeding);
;  capping the fill table from writing more values. Example: trying to input 63/62
;  pieces filled would have the table saying 62/62.
;
;  The end of the address going to be used is this:
;
;  X = (LeftEnd + MiddleLength + RightEnd) - 1
;
;  LeftEnd and/or RightEnd are 0 if there are no pieces for each of them,
;  MiddleLength is basically !Scratchram_GraphicalBar_TempLength. If that or
;  if MiddlePiece = zero (either 16 or 8-bit, this will be zero and will not be
;  included). This can be read as each byte means each 8x8 tile.
;Overwritten/Destroyed:
; -$02 to $09: often used by other routines:
; --$00 to $03 always used due to division routine.
; --$04 to $07 are used by the multiplication routine should right end exist
;   (right end piece is nonzero).
; --$08 to $09 are used for handling fill for each of the 3 groups of bytes
;   (left, middle, and right). Once the routine is done, it's the amount of
;   fill you have input for $00 to $01 (not capped to the value to be full
;   if greater than).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DrawGraphicalBar:
	if !Setting_GraphicalBar_IndexSize == 0
		LDX #$00					;>Index to write all our bytes/8x8s after the first tile.
		REP #$20					;>16-bit A
		LDA $00						;\make a backup on the amount of fill because $00 is used by math routines,
		STA $08						;/and in case if any of the 3 parts gets disabled.
	else
		REP #$30					;>16-bit AXY
		LDX #$0000					;>Index to write all our bytes/8x8s after the first tile.
		LDA $00						;\make a backup on the amount of fill because $00 is used by math routines,
		STA $08						;/and in case if any of the 3 parts gets disabled.
	endif
.LeftEnd
	LDA !Scratchram_GraphicalBar_LeftEndPiece	;\check if the left end was present
	AND #$00FF					;|
	BEQ .Middle					;/
	
	CMP $00						;>Number of pieces on left end (max pieces) compares with number of pieces filled
	BCC ..Full					;>If max pieces is < pieces filled (pieces filled > max), cap it to full
	
	..NotFull
	LDA $00						;>Load the valid non-full value
	
	..Full
	SEP #$20					;\Write only on the first byte of the table.
	STA !Scratchram_GraphicalBar_FillByteTbl	;/
	INX
.Middle
	LDA !Scratchram_GraphicalBar_MiddlePiece	;\Both of these have to be nonzero to include middle.
	BNE +						;|
	JMP .RightEnd					;|
	+						;|
	LDA !Scratchram_GraphicalBar_TempLength		;|
	BNE +						;|
	JMP .RightEnd					;/
	+
	REP #$20
	LDA !Scratchram_GraphicalBar_LeftEndPiece	;>Left end maximum
	AND #$00FF					;
	CMP $00						;>compares with amount filled
	SEP #$20					;
	BCC ..ReachesMiddle				;>If maximum < filled (filled >= maximum)
	
	..EmptyMiddle
	if !Setting_GraphicalBar_IndexSize == 0
		LDA !Scratchram_GraphicalBar_TempLength
		TAY
	else
		REP #$20
		LDA !Scratchram_GraphicalBar_TempLength
		AND #$00FF
		TAY
		SEP #$20
	endif
	...Loop
	LDA #$00					;\Write empty for the middle section
	STA !Scratchram_GraphicalBar_FillByteTbl,x	;/
	
	....Next
	INX						;>next byte/8x8
	DEY
	if !Setting_GraphicalBar_IndexSize == 0
		CPY #$00
	else
		CPY #$0000
	endif
	BNE ...Loop
	JMP .RightEnd

	..ReachesMiddle
	if !Setting_GraphicalBar_IndexSize == 0
		LDA !Scratchram_GraphicalBar_TempLength		;\number of middles to write in Y (used as how many middles, either full, partially or empty left to write)
		TAY						;/
	else
		REP #$20					;\number of middles to write in Y
		LDA !Scratchram_GraphicalBar_TempLength		;|
		AND #$00FF					;|
		TAY						;|
		SEP #$20					;/
	endif
	LDA !Scratchram_GraphicalBar_LeftEndPiece	;\Akaginite's (ID:8691) 16-bit subtract by 8-bit [MiddleFillOnly = TotalFilled - LeftEnd]
	REP #$21					;|>A = 16bit and carry set
	AND #$00FF					;|>Remove high byte
	EOR #$FFFF					;|\Invert the now 16-bit number.
	INC A						;|/>INC does not affect the carry.
	ADC $00						;/>And negative LeftEnd plus filled to get MiddleFillOnly [MiddleFillOnly = (-LeftEnd) + TotalFilled]

	..NumberOfFullMiddles
	
	STA $08						;>middle fill (amount of fill in middle only)
	STA $00						;>store the middlefill in $00 for dividend
	LDA !Scratchram_GraphicalBar_MiddlePiece	;\middlepiece as divisor [NumberOfFull8x8s = MiddleFill/PiecesPer8x8, with NumberOfFull8x8s rounded down.]
	AND #$00FF					;|
	STA $02						;/
	PHY						;>protect number of middle tiles left
	SEP #$30					;>8-bit AXY
	JSL MathDiv					;>$00: number of full bytes/8x8s, $02: fraction byte/8x8 [FractionAmount = MiddleFill MOD PiecesPer8x8]
	LDA $01						;\check if the number of full bytes/8x8s is bigger than 255
	BEQ ...ValidNumbFullMiddles			;/
	
	...InvalidNumbFullMiddles
	LDA #$FF					;\cap the number of full middle 8x8s to max 8-bit number
	STA $00						;/(if for some reason if you want such a length, but shouldn't hurt if you put less)
	
	...ValidNumbFullMiddles
	if !Setting_GraphicalBar_IndexSize == 0
		REP #$20					;>16-bit A
	else
		REP #$30					;>16-bit AXY
	endif
	PLY						;>restore number of middle tiles left
	LDA $00						;>number of full tiles to write
	SEP #$20					;>8-bit A
	BEQ ..FractionAfterFullMiddles			;>skip to fraction because there is no full middle byte/8x8


	...Loop
	LDA !Scratchram_GraphicalBar_MiddlePiece	;\write full tiles
	STA !Scratchram_GraphicalBar_FillByteTbl,x	;/
	
	....Next
	INX						;>next byte/8x8
	DEY						;>subtract number of middles left by 1
	if !Setting_GraphicalBar_IndexSize == 0
		CPY #$00
	else
		CPY #$0000					;\end the loop should the entire middle section be full or higher
	endif
	BEQ ..MiddleDone				;/(avoids adding an extra middle tile, which should be avoided at all cost)
	DEC $00						;\end the loop should all full middles are written.
	BNE ...Loop					;/
	
	..FractionAfterFullMiddles
	LDA $02						;\(remainder) Fraction tiles after all the full middles
	STA !Scratchram_GraphicalBar_FillByteTbl,x	;/
	
	..EmptyAfterFraction
	INX						;>After fraction
	DEY						;>number of bytes/8x8s before the last middle
	if !Setting_GraphicalBar_IndexSize == 0
		CPY #$00					;>countdown before the final middle
	else
		CPY #$0000					;>countdown before the final middle
	endif
	BEQ ..MiddleDone				;>avoid writing the very first empty past the last middle
	
	...Loop
	LDA #$00					;\write empty
	STA !Scratchram_GraphicalBar_FillByteTbl,x	;/
	
	....Next
	INX						;\loop until all middle tiles done.
	DEY
	if !Setting_GraphicalBar_IndexSize == 0
		CPY #$00
	else
		CPY #$0000
	endif
	BNE ...Loop					;/won't add another empty tile.
	
	..MiddleDone
	REP #$20
	LDA !Scratchram_GraphicalBar_LeftEndPiece	;\8-bit left end
	AND #$00FF					;/
	CLC						;\re-include left end, now back to having total amount of filled
	ADC $08						;|pieces
	STA $08						;/
	SEP #$20
.RightEnd
	LDA !Scratchram_GraphicalBar_RightEndPiece	;\check if right end exist
	BEQ .Done					;/
	
	if !Setting_GraphicalBar_SNESMathOnly == 0
		LDA !Scratchram_GraphicalBar_MiddlePiece	;\MiddlePieceTotal = MiddlePiecePer8x8 * Length
		STA $00						;|
		STZ $01						;|
		LDA !Scratchram_GraphicalBar_TempLength		;|
		STA $02						;|
		STZ $03						;/
		if !Setting_GraphicalBar_IndexSize == 0
			JSL MathMul16_16
			REP #$20					;>16-bit A
		else
			PHX						;>Preserve X due to destroyed high byte from the following SEP.
			SEP #$30					;>8-bit AXY
			JSL MathMul16_16				;>$04 to $07: 32 bit product (the total amount in middle)
			REP #$30					;>16-bit AXY
			PLX						;>restore X
		endif
	else
		LDA !Scratchram_GraphicalBar_MiddlePiece	;\MiddlePieceTotal = MiddlePiecePer8x8 * Length
		STA $4202					;|
		LDA !Scratchram_GraphicalBar_TempLength		;|
		STA $4203					;/
		XBA						;\Wait 8 cycles (XBA takes 3, NOP takes 2) for calculation
		XBA						;|
		NOP						;/
		LDA $4216					;\Product in $04-$05
		STA $04						;|
		LDA $4217					;|
		STA $05						;/
		REP #$20					;>16-bit A
	endif

	LDA !Scratchram_GraphicalBar_LeftEndPiece	;\Add by left end piece [TotalLeftEndAndMiddle = MiddlePieceTotal + LeftEnd]
	AND #$00FF					;|
	CLC						;|
	ADC $04						;|This should mark the boundary between middle and right end
	STA $04						;/
	LDA $08						;\RightEndFillOnly = TotalFilled - (MiddlePieceTotal+LeftEnd)
	SEC						;|this result should be less than or equal to 255
	SBC $04						;/>SBC clears the carry should an unsigned underflow occurs ($00 -> $FF) from borrowing. Value should be < 255
	BCC ..EmptyRightEnd				;>carry clear means that the total filled is less than the amount needed to reach the right end.
	STA $00						;>Store right end fill to $00-$01 (still 16-bit to prevent right end from randomly overflowing)
	LDA !Scratchram_GraphicalBar_RightEndPiece	;\RightEnd's maximum (8-bit)
	AND #$00FF					;/
	CMP $00						;>compare with amount of fill only right end (that potentially be over 255)
	BCC ..FullRightEnd				;>If maximum < fill pieces (or right end's filled pieces >= maximum), cap the fill value
	SEP #$20
	LDA $00						;>amount of fill, assuming it's 0 to max.
	BRA ..SetRightEndFill
	
	..EmptyRightEnd
	SEP #$20
	LDA #$00
	
	..FullRightEnd
	SEP #$20
	
	..SetRightEndFill
	STA !Scratchram_GraphicalBar_FillByteTbl,x
	
	.Done
	SEP #$30					;>8-bit AXY
	RTL
if !Setting_Beta32bitMultiplication != 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Unsigned 32bit * 32bit Multiplication
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Argument
; $00-$03 : Multiplicand
; $04-$07 : Multiplier
; Return values
; $08-$0F : Product
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;GHB's note to self:
;$4202 = 1st Multiplicand
;$4203 = 2nd Multiplicand
;$4216 = Product
;During SA-1:
;$2251 = 1st Multiplicand
;$2253 = 2nd Multiplicand
;$2306 = Product

if !sa1 != 0
	!Reg4202 = $2251
	!Reg4203 = $2253
	!Reg4216 = $2306
else
	!Reg4202 = $4202
	!Reg4203 = $4203
	!Reg4216 = $4216
endif

MathMul32_32:
		if !sa1 != 0
			STZ $2250
			STZ $2252
		endif
		REP #$21
		LDY $00
		BNE +
		STZ $08
		STZ $0A
		STY $0C
		BRA ++
+		STY !Reg4202
		LDY $04
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		STZ $0A
		STZ $0C
		LDY $05
		LDA !Reg4216		;>This is always spitting out as 0.
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $08
		LDA $09
		ADC !Reg4216
		LDY $06
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $09
		LDA $0A
		ADC !Reg4216
		LDY $07
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $0A
		LDA $0B
		ADC !Reg4216
		STA $0B
		
++		LDY $01
		BNE +
		STY $0D
		BRA ++
+		STY !Reg4202
		LDY $04
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		LDY #$00
		STY $0D
		LDA $09
		ADC !Reg4216
		LDY $05
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $09
		LDA $0A
		ADC !Reg4216
		LDY $06
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $0A
		LDA $0B
		ADC !Reg4216
		LDY $07
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $0B
		LDA $0C
		ADC !Reg4216
		STA $0C
		
++		LDY $02
		BNE +
		STY $0E
		BRA ++
+		STY !Reg4202
		LDY $04
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		LDY #$00
		STY $0E
		LDA $0A
		ADC !Reg4216
		LDY $05
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $0A
		LDA $0B
		ADC !Reg4216
		LDY $06
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $0B
		LDA $0C
		ADC !Reg4216
		LDY $07
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $0C
		LDA $0D
		ADC !Reg4216
		STA $0D
		
++		LDY $03
		BNE +
		STY $0F
		BRA ++
+		STY !Reg4202
		LDY $04
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		LDY #$00
		STY $0F
		LDA $0B
		ADC !Reg4216
		LDY $05
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $0B
		LDA $0C
		ADC !Reg4216
		LDY $06
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $0C
		LDA $0D
		ADC !Reg4216
		LDY $07
		STY !Reg4203
		if !sa1 != 0
			STZ $2254	;>Multiplication actually happens when $2254 is written.
			NOP		;\Wait till multiplication is done
			BRA $00		;/
		endif
		
		STA $0D
		LDA $0E
		ADC !Reg4216
		STA $0E
++		SEP #$20
		RTL
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; unsigned 16bit / 16bit Division
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Arguments
; $00-$01 : Dividend
; $02-$03 : Divisor
; Return values
; $00-$01 : Quotient
; $02-$03 : Remainder
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MathDiv:	REP #$20
		ASL $00
		LDY #$0F
		LDA.w #$0000
-		ROL A
		CMP $02
		BCC +
		SBC $02
+		ROL $00
		DEY
		BPL -
		STA $02
		SEP #$20
		RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Unsigned 32bit / 16bit Division
; By Akaginite (ID:8691), fixed the overflow
; bitshift by GreenHammerBro (ID:18802)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Arguments
; $00-$03 : Dividend
; $04-$05 : Divisor
; Return values
; $00-$03 : Quotient
; $04-$05 : Remainder
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MathDiv32_16:	REP #$20
		ASL $00
		ROL $02
		LDY #$1F
		LDA.w #$0000
-		ROL A
		BCS +
		CMP $04
		BCC ++
+		SBC $04
		SEC
++		ROL $00
		ROL $02
		DEY
		BPL -
		STA $04
		SEP #$20
		RTL
if !sa1 == 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 16bit * 16bit unsigned Multiplication
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Argusment
; $00-$01 : Multiplicand
; $02-$03 : Multiplier
; Return values
; $04-$07 : Product
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MathMul16_16:	REP #$20
		LDY $00
		STY $4202
		LDY $02
		STY $4203
		STZ $06
		LDY $03
		LDA $4216
		STY $4203
		STA $04
		LDA $05
		REP #$11
		ADC $4216
		LDY $01
		STY $4202
		SEP #$10
		CLC
		LDY $03
		ADC $4216
		STY $4203
		STA $05
		LDA $06
		CLC
		ADC $4216
		STA $06
		SEP #$20
		RTL
else
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 16bit * 16bit unsigned Multiplication SA-1 version
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Argusment
; $00-$01 : Multiplicand
; $02-$03 : Multiplier
; Return values
; $04-$07 : Product
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MathMul16_16:	STZ $2250
		REP #$20
		LDA $00
		STA $2251
		ASL A
		LDA $02
		STA $2253
		BCS +
		LDA.w #$0000
+		BIT $02
		BPL +
		CLC
		ADC $00
+		CLC
		ADC $2308
		STA $06
		LDA $2306
		STA $04
		SEP #$20
		RTL
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Convert fill amount to tile number
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;These are tables to convert whats in !Scratchram_GraphicalBar_FillByteTbl to tile numbers.
GraphicalBar_LeftEnd8x8s:
	;    0   1   2   3
	db $36,$37,$38,$39
GraphicalBar_Middle8x8s:
	;    0   1   2   3   4   5   6   7   8
	db $55,$56,$57,$58,$59,$65,$66,$67,$68
GraphicalBar_RightEnd8x8s:
	;    0   1   2   3
	db $50,$51,$52,$53
ConvertFillToTileNumb:
.ConvertFillTo8x8
	PHB						;>Preserve bank (so that table indexing work properly)
	PHK						;>push current bank
	PLB						;>pull out as regular bank

	if !Setting_GraphicalBar_IndexSize == 0
		LDX #$00
	else
		REP #$10								;>16-bit XY
		LDX #$0000								;>The index for what byte tile position to write.
	endif

.LeftEndTranslate
	LDA !Scratchram_GraphicalBar_LeftEndPiece	;\can only be either 0 or the correct number of pieces listed in the table.
	BEQ .MiddleTranslate				;/
	if !Setting_GraphicalBar_IndexSize == 0
		LDA !Scratchram_GraphicalBar_FillByteTbl
		TAY
	else
		REP #$20
		LDA !Scratchram_GraphicalBar_FillByteTbl
		AND #$00FF
		TAY
		SEP #$20
	endif
	LDA GraphicalBar_LeftEnd8x8s,y
	STA !Scratchram_GraphicalBar_FillByteTbl
	INX						;>next tile

.MiddleTranslate
	LDA !Scratchram_GraphicalBar_MiddlePiece	;\check if middle exist.
	BEQ .RightEndTranslate				;|
	LDA !Scratchram_GraphicalBar_TempLength		;|
	BEQ .RightEndTranslate				;/

	if !Setting_GraphicalBar_IndexSize == 0
		LDA !Scratchram_GraphicalBar_TempLength
		STA $00
	else
		REP #$20
		LDA !Scratchram_GraphicalBar_TempLength
		AND #$00FF
		STA $00
	endif
	..Loop
	if !Setting_GraphicalBar_IndexSize == 0
		LDA !Scratchram_GraphicalBar_FillByteTbl,x
		TAY
	else
		LDA !Scratchram_GraphicalBar_FillByteTbl,x	;\amount of filled, indexed
		AND #$00FF					;|
		TAY						;/
		SEP #$20
	endif
	LDA GraphicalBar_Middle8x8s,y			;\amount filled as graphics
	STA !Scratchram_GraphicalBar_FillByteTbl,x	;/
	
	...Next
	INX
	if !Setting_GraphicalBar_IndexSize != 0
		REP #$20
	endif
	DEC $00
	BNE ..Loop
	
	SEP #$20

	.RightEndTranslate
	LDA !Scratchram_GraphicalBar_RightEndPiece
	BEQ .Done
	if !Setting_GraphicalBar_IndexSize == 0
		LDA !Scratchram_GraphicalBar_FillByteTbl,x
		TAY
	else
		REP #$20
		LDA !Scratchram_GraphicalBar_FillByteTbl,x
		AND #$00FF
		TAY
		SEP #$20
	endif
	LDA GraphicalBar_RightEnd8x8s,y
	STA !Scratchram_GraphicalBar_FillByteTbl,x
	
	.Done
	SEP #$30					;>Just in case
	PLB						;>Pull bank
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;16-bit hex to 4 (or 5)-digit decimal subroutine
;Input:
;$00-$01 = the value you want to display
;Output:
;!DigitTable to !DigitTable+4 = a digit 0-9 per byte table (used for
; 1-digit per 8x8 tile):
; +$00 = ten thousands
; +$01 = thousands
; +$02 = hundreds
; +$03 = tens
; +$04 = ones
;
;!DigitTable is address $02 for normal ROM and $04 for SA-1.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ConvertToDigits:
	if !sa1 == 0
		PHX
		PHY

		LDX #$04	;>5 bytes to write 5 digits.

		.Loop
		REP #$20	;\Dividend (in 16-bit)
		LDA $00		;|
		STA $4204	;|
		SEP #$20	;/
		LDA.b #10	;\base 10 Divisor
		STA $4206	;/
		JSR .Wait	;>wait
		REP #$20	;\quotient so that next loop would output
		LDA $4214	;|the next digit properly, so basically the value
		STA $00		;|in question gets divided by 10 repeatedly. [Value/(10^x)]
		SEP #$20	;/
		LDA $4216	;>Remainder (mod 10 to stay within 0-9 per digit)
		STA $02,x	;>Store tile

		DEX
		BPL .Loop

		PLY
		PLX
		RTL

		.Wait
		JSR ..Done		;>Waste cycles until the calculation is done
		..Done
		RTS
	else
		PHX
		PHY

		LDX #$04

		.Loop
		REP #$20		;>16-bit XY
		LDA.w #10		;>Base 10
		STA $02			;>Divisor (10)
		SEP #$20		;>8-bit XY
		JSL MathDiv		;>divide
		LDA $02			;>Remainder (mod 10 to stay within 0-9 per digit)
		STA.b !DigitTable,x	;>Store tile

		DEX
		BPL .Loop

		PLY
		PLX
		RTL
	endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Remove leading zeros, uses my 4/5 hex to dec converter.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;inserted if the user enabled showing numbers and have it right-aligned.
;
;It's considered fixed digits position if the user does any of these things:
;-Disabled aligned digits
;-Have right-aligned digits when the user set to display only current HP
; (have !Setting_SpriteHP_DisplayNumerical set to 1).

if !Setting_SpriteHP_DisplayNumerical != 0
	if or(equal(!Setting_EnemyHPAlignDigits, 0), and(equal(!Setting_EnemyHPAlignDigits, 2), equal(!Setting_SpriteHP_DisplayNumerical, 1)))
		RemoveLeadingZeros:
		PHY
		LDX #$00					;>Start at leftmost digit (thousands)
		LDY #$FC					;>Load blank tile (out of loop for faster speed, no reload)

		.Loop
		LDA !DigitTable,x				;\If digit not zero, don't replace current digit as well as the rest
		BNE .NonZeroDigit				;/(so 0303 would be 303.)
		STY.b !DigitTable,x				;>Remove leading zero
		INX						;\Next digit (one less than the number of digits-1 so it displays a single 0)
		CPX.b #$04					;/
		BCC .Loop					;>BCC only branches when less than (so = or higher means branch isn't taken)

		.NonZeroDigit
		PLY
		RTL
	endif
endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Left-aligned number display (single number). Useful for removing leading
;spaces in the digits (so if it tries to display [---3], it's displayed as
;[3***] where * indicates garbage (unwritten) bytes).
;
; Input:
;  -!DigitTable to !DigitTable+4 = a digit 0-9 per byte (used for 1-digit 
;   per 8x8 tile, using my 4/5 hexdec routine; ordered from high to low digits)
;  -X = the location within the table to place the string in.
; Output:
;  -!Scratchram_CharacterTileTable = A table containing a string of numbers
;   with unnecessary spaces and zeroes stripped out.
;  -X = the location to place string AFTER the numbers. Also use for
;   indicating the last digit (or any tile) number for how many tiles to
;   be written to the status bar, overworld border, etc.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
if !Setting_EnemyHPAlignDigits != 0 && !Setting_SpriteHP_DisplayNumerical != 0
	LeftAlignedDigit:
	LDY #$00				;>Start looking at the leftmost (highest) digit
	LDA #$00				;\When the value is 0, display it as single digit as zero
	STA !Scratchram_CharacterTileTable,x	;/(gets overwritten should nonzero input exist)

	.Loop
	LDA.w !DigitTable|!dp,Y			;\If there is a leading zero, move to the next digit to check without moving the position to
	BEQ ..NextDigit				;/place the tile in the table
	
	..FoundDigit
	LDA.w !DigitTable|!dp,Y			;\Place digit
	STA !Scratchram_CharacterTileTable,x	;/
	INX					;>Next string position in table
	INY					;\Next digit
	CPY #$05				;|
	BCC ..FoundDigit			;/
	RTL
	
	..NextDigit
	INY			;>1 digit to the right
	CPY #$05		;\Loop until no digits left (minimum is 1 digit)
	BCC .Loop		;/
	INX			;>Next 8x8 tile after the last digit
	RTL
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Prevent glitches regarding too much digits.
;Output:
;-Carry: Clear if digits didn't exceed the digit limit.
;-"-" symbols are written to indicate excess digits.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
if and(less(!Setting_EnemyHPMaxDigits, !EnemyHPMaxUnsignIntegerMaxDigit), notequal(!Setting_EnemyHP_ExcessDigitProt, 0))
	ExcessiveCharacterProtection:
	LDA !Freeram_SprTbl_CurrHPLow,x
	SEC
	SBC.b #(10**!Setting_EnemyHPMaxDigits)
	if !Setting_SpriteHP_TwoByteHP != 0
		LDA !Freeram_SprTbl_CurrHPHi,x
		SBC.b #(10**!Setting_EnemyHPMaxDigits)>>8
	endif
	if !Setting_SpriteHP_DisplayNumerical == 2
		BCS .DisplayDash

		LDA !Freeram_SprTbl_MaxHPLow,x
		SEC
		SBC.b #(10**!Setting_EnemyHPMaxDigits)
		if !Setting_SpriteHP_TwoByteHP != 0
			LDA !Freeram_SprTbl_MaxHPHi,x
			SBC.b #(10**!Setting_EnemyHPMaxDigits)>>8
		endif
		BCC .Safe
	else
		BCC .Safe
	endif
	.DisplayDash
	LDX.b #(!EnemyHPMaxCharacterSize*!StatusBarFormat)-!StatusBarFormat
	
	..Loop
	LDA #$27
	STA !EnemyHPNumericalPosition,x
	DEX #!StatusBarFormat
	BPL ..Loop
	
	SEC
	RTL
	
	.Safe
	CLC
	RTL
endif
print "" ;>linebreak