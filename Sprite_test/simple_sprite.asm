;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sprite Template
;;
;; Description: It's just a 16x16 custom sprite use for testing with the HP meter patch.
;;
;; NOTE: Due to a bug with asar's leaking labels in macros, and that the labels here
;; uses sublabels, this sprite does NOT use pixi's routines due to them using macros.
;; Hopefully this bug gets fixed soon, it's really annoying.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	;This stuff was here due to pixi have the SA-1 values in defines being renamed, so a transfer
	;was needed:
	!sa1 = !SA1		;>case sensitive.
	!sprite_slots = !SprSize

	incsrc "EnemyHPDefines/EnemyHP.asm"
	incsrc "EnemyHPDefines/GraphicalBarDefines.asm"
	
	!Setting_StompBounceBack	= 1	;>bounce player away when stomping: 0 = false, 1 = true.
	!Setting_DamagePlayer		= 1	;>0 = harmless, 1 = damage player on contact (besides stomping)
	
	!HealingAmount		= 3		;>amount of HP recovered periodically (0 = no heal). The periods are on the following define.
	!HealingPeriodicSpd	= $7F		;>pick ONLY these values: $00 (frequent), $01, $03, $07, $0F, $1F, $3F,$7F, $FF (not as frequent). This uses $7E0014.
	!HealingSfxNum		= $0A		;\sound effects played when healing.
	!HealingSfxRam		= $1DF9|!Base2	;/

	!HPToStart		= 300		;>Decimal, amount of HP the enemy has.
	!StompDamage		= 5		;>Decimal, amount of damage from stomping.
	!FireballDmg		= 3		;>Decimal, amount of damage from player's fireball.
	!YoshiFireball		= 50		;>Decimal, amount of damage from yoshi's fireball.
	!BounceDamage		= 2		;>Decimal, amount of damage from bounce blocks.
	!CarryableKickedSpr	= 6		;>Decimal, amount of damage from other sprites (shell, for example)
	!CapeSpinDamage		= 4		;>Decimal, amount of damage from cape spin.

	;symbolic names for ram addresses
	!SPRITE_Y_SPEED		= !AA
	!SPRITE_X_SPEED		= !B6
	!SPRITE_STATE		= !C2
	!SPRITE_STATUS		= !14C8
	!InvulnerabilityTimer	= !1540		;>flashing animation + invulnerability timer.
	!SPR_OBJ_STATUS		= !1588

	!HPLowEnoughToShowAltGfx	= !HPToStart/2		;>HP to get below to start showing alternative graphics
	!TILE				= $00
	!TILE_LowHealth			= $02			;>16x16 tile to use when HP is below !HPLowEnoughToShowAltGfx.
;Other define(s) below:
	!NumOfSprSlot	= 12	;>In case of SA-1

	!DmgSfxNumb		= $28
	!DmgSfxRam		= $1DFC|!Base2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sprite init JSL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print "INIT ",pc
	Mainlabel:
	.StartWithFullHP
	LDA.b #!HPToStart		;\Full HP (low byte)
	STA !Freeram_SprTbl_CurrHPLow,x	;|
	STA !Freeram_SprTbl_MaxHPLow,x	;/
	LDA.b #!HPToStart>>8		;\Full HP (High byte)
	STA !Freeram_SprTbl_CurrHPHi,x	;|
	STA !Freeram_SprTbl_MaxHPHi,x	;/
	RTL


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sprite code JSL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR SPRITE_CODE_START
	PLB
	RTL


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; main
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FootYpos:
	dw $0018,$0028,$0028
if !Setting_StompBounceBack
BouncePlayerAway:
	db $E0,$20 ;>Same as chargin chuck.
endif

MainReturn:
	RTS
SPRITE_CODE_START:
	.BlinkIfInvulnerable
	LDA !InvulnerabilityTimer,x	;\Blink during invulnerability period (placed before
	BEQ ..NoBlink			;|$9D freeze check so it still shows during freeze)
	LDA $14				;|
	AND.b #%00000010		;|\2 frames show and 2 frames of no-show
	BNE ..NoGFX			;|/
	..NoBlink
	JSR SUB_GFX
	..NoGFX

	.FreezeCheck
	LDA $9D				;\Don't do anything during freeze.
	BNE MainReturn			;/
	if !Setting_SpriteHP_BarAnimation != 0
		.RemoveRecordWhenSwitchingHPs
		TXA					;>Don't worry, this copies X, not just transfer
		CMP !Freeram_SprHPCurrSlot		;>Compare with the slot the HP bar is using
		BEQ ..ItsOnThisSprite			;>If HP bar is on this current sprite, don't delete record
		JSL !DummyJSL_EnemyHP_GetPercentHP	;>Get current percent HP
		LDA $00					;\Remove Record effect (make them the same)
		STA !Freeram_SprTbl_RecordEfft,x	;/
		..ItsOnThisSprite
	endif
	if !HealingAmount != 0
		LDA !Freeram_SprTbl_CurrHPLow,x			;\CMP is like SBC. if currentHP - MaxHP results an unsigned underflow (which causes a barrow; carry clear)
		CMP !Freeram_SprTbl_MaxHPLow,x			;|then allow healing
		if !Setting_SpriteHP_TwoByteHP != 0
			LDA !Freeram_SprTbl_CurrHPHi,x
			SBC !Freeram_SprTbl_MaxHPHi,x
		endif
		BCS +						;/
		LDA $14						;\frame counter modulo by powers of 2 value
		AND.b #!HealingPeriodicSpd			;|
		BNE +						;/>if remainder isn't 0, don't heal on this time
		REP #$20					;\heal sprite
		LDA.w #!HealingAmount				;|
		STA $00						;|
		SEP #$20					;|
		JSR Heal					;/
		if !Setting_SpriteHP_BarAnimation != 0
			JSL !DummyJSL_EnemyHP_GetPercentHP	;\remove record effect (without the condition of not selecting this sprite)
			LDA $00					;|
			STA !Freeram_SprTbl_RecordEfft,x	;/
		endif
		if !HealingSfxNum != 0
			LDA #!HealingSfxNum
			STA !HealingSfxRam
		endif
		+
	endif
	JSR MainSpriteClipA		;>Get hitbox A of main sprite

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Mario contact (mainly jumping on this sprite)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.HitboxWithMario
	JSL $03B664			;>Get clipping with player (B).
	JSL $03B72B			;>Check contact
	BCC .NoContact			;>No interaction if not contacting.
	;------------------------------------------------------------------------------
	;Player touching sprite
	;------------------------------------------------------------------------------
	.Contact
	LDA !InvulnerabilityTimer,x	;\Don't drain-damage every frame during touch
	BNE .NoContact			;/
	REP #$20
	LDA $00		;\Protect hitbox data
	PHA		;/
	SEP #$20

	LDA !14D4,x	;\Sprite Y positon 16-bit into $00-$01
	XBA		;|
	LDA !D8,x	;|
	REP #$20	;|
	STA $00		;/
	LDA $187A|!Base2	;\Positon of the player's bottommost hitbox depending on riding yoshi
	ASL			;|>Index times 2 because the positions are 2-bytes.
	TAY			;/
	LDA $96			;\The position where bottom hitbox feet is
	CLC			;|above the sprite (move down TOWARDS the sprite's Y pos).
	ADC FootYpos,y		;/
	CMP $00			;>Compare with sprite's y pos
	SEP #$20
	BMI ..MarioStomps	;>If mario is above, go to damage sprite

	..SpriteDamageMario
	if !Setting_DamagePlayer != 0
		JSL $00F5B7		;>Hurt player by touching below/sides
	endif
	BRA ..Restore

	..MarioStomps
	LDA.b #10			;\Set timer to prevent multi-hit rapid stomping drain HP
	STA !InvulnerabilityTimer,x	;/(happens very easily when hitting sprites on top two corners).
	JSR ConsecutiveStomps
	REP #$20
	LDA.w #!StompDamage			;\Amount of damage
	STA $00					;/
	SEP #$20
	JSL !DummyJSL_EnemyHP_LoseHP		;>Lose HP
	LDA !Freeram_SprTbl_CurrHPLow,x		;\If HP != 0, don't kill
	ORA !Freeram_SprTbl_CurrHPHi,x		;|
	BNE ...NoDeath				;/
	JSR SpinjumpKillSprite			;>Kill sprite
	BRA ...SkipBouncePlayerAwayAndSfx

	...NoDeath
	if !Setting_StompBounceBack != 0
		LDY #$00
		LDA !E4,x		;\SpriteXPos - MarioXPos
		SEC			;|
		SBC $94			;|
		LDA !14E0,x		;|
		SBC $95			;/
		BPL ....MarioRight	;>mario is on the right side of the sprite
		INY
		
		....MarioRight
		LDA BouncePlayerAway,y
		STA $7B
	endif
	LDA #!DmgSfxNumb	;\SFX
	STA !DmgSfxRam		;/

	...SkipBouncePlayerAwayAndSfx
	LDA $15			;\Bounce at very different y speeds depending on holding jump or not.
	BPL ....NotHoldingJump	;/
	LDA #$A8
	BRA ....SetYSpd

	....NotHoldingJump
	LDA #$D0		;

	....SetYSpd
	STA $7D			;>Player shoots up

	..Restore
	REP #$20
	PLA		;\Restore hitbox
	STA $00		;/
	SEP #$20

	.NoContact
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Extended sprite (Mario and Yoshi's fireball Contact)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.HitboxWithExtSpr
	LDY.b #$10-1			;>Slots 0-9 of extended sprites

	..Loop
	LDA $170B|!Base2,y	;>Extended sprite number
	BEQ ...NextSlot		;>next if not-existent
	CMP #$05		;\Player's fireball
	BEQ ...Fireball		;/
	CMP #$11		;\Yoshi's fireball after eating
	BEQ ...Fireball		;/a red shell
	BRA ...NextSlot		;>Others = next

	...Fireball
	JSR ExtSprFireballClipB	;>Get contact with current fireball ext spr slot.
	JSL $03B72B		;>Check contact between A and B.
	BCC ...NextSlot		;>No contact, check other extended sprite.
	;------------------------------------------------------------------------------
	;here is where the contact happens. Make sure that it goes to [...NextSlot]
	;so that in case if 2 fireballs contacts at the same frame, each will run this.
	;Y = current extended sprite slot.
	;------------------------------------------------------------------------------
	...Contact
	LDA !Freeram_SprTbl_CurrHPLow,x		;\If HP is already 0 and another sprite within the same frame
	ORA !Freeram_SprTbl_CurrHPHi,x		;/hits this boss, make it ignore the boss (pass through already-dead boss)
	ORA !InvulnerabilityTimer,x		;>And also no invulnerabilty timer running.
	BEQ ...ExitLoop				;

	LDA.b #10				;\Just to show the blinking and in case if projectile penetrates.
	STA !InvulnerabilityTimer,x		;/
	REP #$20
	LDA $00			;\Preserve $00 (used for contact checking, about to be used
	PHA			;/for damage value)
	SEP #$20

	LDA $170B|!Base2,y	;>Extended sprite number (do not clear it before reaching here)
	CMP #$05		;\Player's fireball
	BEQ ....PlayerFireball	;/
	CMP #$11		;\Yoshi's fireball
	BEQ ....YoshiFireball	;/
	JMP ...NextSlot

	....PlayerFireball
	REP #$20		;\Damage from player's fireball
	LDA.w #!FireballDmg	;|
	STA $00			;|
	SEP #$20		;|
	BRA ....Damage		;/

	....YoshiFireball
	REP #$20		;\Damage from yoshi's fireball
	LDA.w #!YoshiFireball	;|
	STA $00			;|
	SEP #$20		;/

	....Damage
	JSL !DummyJSL_EnemyHP_LoseHP	;>Lose HP
	LDA !Freeram_SprTbl_CurrHPLow,x	;\If HP != 0, don't kill
	ORA !Freeram_SprTbl_CurrHPHi,x	;|
	BNE .....NoDeath		;/
	JSR SpinjumpKillSprite		;>Make sprite die (sets !14C8,x and uses whats marked * to prevent executing multiple times).
	BRA .....SkipSfx

	.....NoDeath
	LDA #!DmgSfxNumb			;\SFX
	STA !DmgSfxRam				;/

	.....SkipSfx
	REP #$20
	PLA			;\Restore hitbox data.
	STA $00			;/
	SEP #$20
	LDA #$00		;\Delete fireball (no penetrate).
	STA $170B|!Base2,y		;/there is no STZ $XXXX,y
	PHX			;>Protect main sprite slot
	PHY			;>Protect extended sprite slot
	TYX			;>Transfer extended sprite slot number to X (Y will be smoke sprite number)
	JSR SpawnSmokeByExtSpr
	PLY			;>Restore Y
	PLX			;>Restore X

	...NextSlot
	DEY			;>Next slot
	BMI ...ExitLoop		;\Loop until out of 0-9 (inclusive) range
	JMP ..Loop		;/
	...ExitLoop

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Bounce blocks
	;
	;Note to self: thankfully, they are mostly 16x16
	;shaped.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.HitboxWithBounceBlocks
	LDY.b #$04-1

	..Loop
	LDA $1699|!Base2,y	;\Non-existent bounce block = next slot
	BEQ ...NextSlot		;/

	CMP #$07		;\A spinning turn block does not hurt foes.
	BEQ ...NextSlot		;/

	...SpriteHit
	JSR BounceSprClipB	;>Get bounce sprite clipping into B.
	JSL $03B72B		;>Check contact between A and B.
	BCC ...NextSlot		;>No contact, check other extended sprite.
	;------------------------------------------------------------------------------
	;here is where the contact happens. Make sure that it goes to [...NextSlot]
	;so that in case if 2 bounce contacts at the same frame, each will run this.
	;Y = current bounce sprite slot.
	;------------------------------------------------------------------------------
	...Contact
	LDA !InvulnerabilityTimer,x		;\Prevent damaging sprite multiple frames
	BEQ ....RunBounceBlockDmg		;|during touching a bounce sprite.
	JMP .SkipBounceBlkDmg			;/

	....RunBounceBlockDmg	
	LDA.b #15			;\Prevent another damage on next frame
	STA !InvulnerabilityTimer,x	;/

	REP #$20
	LDA $00			;\Preserve hitbox data
	PHA			;/
	LDA.w #!BounceDamage	;\Damage from bounce blocks
	STA $00			;/
	SEP #$20
	JSL !DummyJSL_EnemyHP_LoseHP	;>Lose HP
	LDA !Freeram_SprTbl_CurrHPLow,x	;\If HP != 0, don't kill
	ORA !Freeram_SprTbl_CurrHPHi,x	;|
	BNE ....NoDeath			;/
	JSR SpinjumpKillSprite	;>Make sprite die
	BRA ....SkipSfx

	....NoDeath
	LDA #!DmgSfxNumb	;\SFX
	STA !DmgSfxRam		;/
	
	....SkipSfx
	REP #$20
	PLA			;\Restore hitbox data
	STA $00			;/
	SEP #$20

	...NextSlot
	DEY			;>Next slot
	BPL ..Loop		;>Loop if current slot is valid

	.SkipBounceBlkDmg
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Other (normal) sprites.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.HitboxWithOtherSpr
	LDY.b #!NumOfSprSlot-1

	..Loop
	TYA			;\Don't interact with its own slot/self.
	CMP $15E9|!Base2	;|
	BNE +
	JMP ...NextSlot		;/>branch distance limit.

	+
	LDA !14C8,y		;>Sprite state
	CMP #$08		;\No interaction on non-existent sprite and any form of death sprite.
	BCS +
	JMP ...NextSlot
	+
	CMP #$0C		;/
	BCC +
	JMP ...NextSlot		;>Powerup from goal as well as invalid states.
	+
	
	...ValidStates
	JSR CarryableKickedClipB	;>You may need to change this if you have sprites other than "16x16" dimension.
	JSL $03B72B			;>If sprite B hits this sprite
	BCC ...NextSlot
	;------------------------------------------------------------------------------
	;here is where the contact happens. Make sure that it goes to [...NextSlot] so
	;that in case if 2 bounce contacts at the same frame, each will run this. 
	;
	;Y = current bounce sprite slot.
	;------------------------------------------------------------------------------
	...Contact
	LDA !Freeram_SprTbl_CurrHPLow,x		;\If HP is already 0 and another sprite within the same frame
	ORA !Freeram_SprTbl_CurrHPHi,x		;|hits this boss, make it ignore the boss (pass through already-dead boss)
	BEQ ...ExitLoop				;/

	;Accepts states #$08 to #$0B here. My following example only includes carryable/kicked to damage.
	LDA !14C8,y			;\only allow kicked/carryable sprites
	CMP #$09			;|
	BEQ ....CarryableKickedSpdChk	;|
	CMP #$0A			;|
	BEQ ....CarryableKickedSpdChk	;/
	BRA ...NextSlot			;>check next slot

	....CarryableKickedSpdChk
	.....XSpeed
	LDA !B6,y		;\If X speed already positive, don't flip
	BPL ......Positive	;/
	EOR #$FF		;\Invert speed (absolute value)
	INC			;/

	......Positive
	CMP #$08		;\If absolute speed bigger than #$08, hurt boss
	BCS ...Damage		;/if not, check other speed

	.....YSpeed
	LDA !AA,y		;\If Y speed already positive, don't flip
	BPL ......Positive	;/
	EOR #$FF		;\Invert speed (absolute value)
	INC			;/

	......Positive
	CMP #$08		;\If absolute speed less than #$08 on both, 
	BCC ...NextSlot		;/no damage/interaction

	...Damage
	LDA.b #10			;\flashing animation
	STA !InvulnerabilityTimer,x	;/
	REP #$20
	LDA $00				;\Preserve $00 used by hitbox A
	PHA				;/
	LDA.w #!CarryableKickedSpr	;\The damage
	STA $00				;/
	SEP #$20
	JSL !DummyJSL_EnemyHP_LoseHP	;>Lose HP
	LDA !Freeram_SprTbl_CurrHPLow,x	;\If HP != 0, don't kill
	ORA !Freeram_SprTbl_CurrHPHi,x	;|
	BNE ....NoDeath			;/
	JSR SpinjumpKillSprite
	BRA ....SkipSfx

	....NoDeath
	LDA #!DmgSfxNumb		;\SFX
	STA !DmgSfxRam			;/
	....SkipSfx
	LDA #$02			;\Kill sprite (falling down screen).
	STA !14C8,y			;/
	LDA #$C8			;\Make it jump up before falling.
	STA !AA,y			;/
	
	.....XSpeedDeflect
	LDA !B6,y			;\same speed as smw's
	BMI ......Leftwards
	......Rightwards
	LDA #$F0
	BRA +
	......Leftwards
	LDA #$10
	+
	STA !B6,y
	REP #$20			;\Restore hitbox A
	PLA				;|
	STA $00				;|
	SEP #$20			;/

	...NextSlot
	DEY
	BMI ...ExitLoop			;>long way up that branches cannot jump that far.
	JMP ..Loop

	...ExitLoop
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Cape spin
	;
	;Probably the first non-instant-kill damage from a
	;cape spin. 
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.HitboxWithCapeSpin
	LDA !InvulnerabilityTimer,x	;\Don't damage multiple frames after the first hit.
	BNE ..NoCapeHit			;/

	JSR CapeClipB		;>Get cape's hitbox
	BCC ..NoCapeHit		;>If cape spin non-existent, don't assume it exist
	JSL $03B72B		;>Check if cape's hitbox hits this current sprite
	BCC ..NoCapeHit		;>If box A and B not touching, don't assume touching.
	;------------------------------------------------------------------------------
	;here is where the contact happens. Since there is only one cape and not being
	;a slot, a loop isn't necessary and you don't need to go to [...NextSlot] when
	;its done.
	;------------------------------------------------------------------------------
	..Contact
	LDA #$08			;\Make sprite invulnerable the inital hit.
	STA !InvulnerabilityTimer,x	;/
	REP #$20
	LDA $00				;\$00 going to be used as damage instead of hitbox-related
	PHA				;/
	LDA.w #!CapeSpinDamage		;\Amount of damage
	STA $00				;/
	SEP #$20
	JSL !DummyJSL_EnemyHP_LoseHP	;>Lose HP
	LDA !Freeram_SprTbl_CurrHPLow,x	;\If HP != 0, don't kill
	ORA !Freeram_SprTbl_CurrHPHi,x	;|
	BNE ...NoDeath			;/
	JSR SpinjumpKillSprite
	BRA ...SkipSfx

	...NoDeath
	LDA #!DmgSfxNumb		;\SFX
	STA !DmgSfxRam			;/

	...SkipSfx
	REP #$20
	PLA				;\Restore hitbox data
	STA $00				;/
	SEP #$20

	..NoCapeHit ;>You must have this in existent though.
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GENERIC GRAPHICS ROUTINE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SUB_GFX:
		JSR GET_DRAW_INFO	; after: Y = index to sprite OAM ($300)
					;  $00 = sprite x position relative to screen boarder 
					;  $01 = sprite y position relative to screen boarder  

		LDA $00			; set x position of the tile
		STA $0300|!Base2,y

		LDA $01			; set y position of the tile
		STA $0301|!Base2,y

		LDA !Freeram_SprTbl_CurrHPHi,x
		XBA
		LDA !Freeram_SprTbl_CurrHPLow,x
		REP #$20
		CMP.w #!HPLowEnoughToShowAltGfx
		SEP #$20
		BCS HighHP
		;LowHP
		LDA #!TILE_LowHealth
		BRA +
		
		HighHP:
		LDA #!TILE
		+
		STA $0302|!Base2,y

		LDA !15F6,x		; get sprite palette info
		ORA $64			; add in the priority bits from the level settings
		STA $0303|!Base2,y	; set properties

		LDY #$02		; #$02 means the tiles are 16x16
		LDA #$00		; This means we drew one tile
		JSL $01B7B3
		RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SUB_9A04:
	LDA !SPR_OBJ_STATUS,x 
	BMI LBL_01 
	LDA #$00    
	LDY !15B8,x 
	BEQ LBL_02 
LBL_01:
	LDA #$18
LBL_02:
	STA !SPRITE_Y_SPEED,x   
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GET_DRAW_INFO
; This is a helper for the graphics routine.  It sets off screen flags, and sets up
; variables.  It will return with the following:
;
;		Y = index to sprite OAM ($300)
;		$00 = sprite x position relative to screen boarder
;		$01 = sprite y position relative to screen boarder  
;
; It is adapted from the subroutine at $03B760
;
;GHB edit: rewrite the spacing/tabbing as the comments fail to align properly.
;Note: using notepad++ the tab size = 8 for better viewing.
;(Settings - Preferences - Language: Tab settings as of version 7.5.6)
;
;Feel free to copy/use this if you want this style alignment.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SPR_T1:
	db $0C,$1C
SPR_T2:
	db $01,$02

GET_DRAW_INFO:
	STZ !186C,x				; reset sprite offscreen flag, vertical
	STZ !15A0,x				; reset sprite offscreen flag, horizontal
	LDA !E4,x				; \
	CMP $1A					;  | set horizontal offscreen if necessary
	LDA !14E0,x				;  |
	SBC $1B					;  |
	BEQ ON_SCREEN_X				;  |
	INC !15A0,x				; /

ON_SCREEN_X:
	LDA !14E0,x			; \
	XBA				;  |
	LDA !E4,x			;  |
	REP #$20			;  |
	SEC				;  |
	SBC $1A				;  | mark sprite invalid if far enough off screen
	CLC				;  |
	ADC.w #$0040			;  |
	CMP.w #$0180			;  |
	SEP #$20			;  |
	ROL A				;  |
	AND #$01			;  |
	STA !15C4,x			; / 
	BNE INVALID			; 
	
	LDY #$00			; \ set up loop:
	LDA !1662,x			;  |
	AND #$20			;  | if not smushed (1662 & 0x20), go through loop twice
	BEQ ON_SCREEN_LOOP		;  | else, go through loop once
	INY				; / 
ON_SCREEN_LOOP:
	LDA !D8,x			; \ 
	CLC				;  | set vertical offscreen if necessary
	ADC SPR_T1,y			;  |
	PHP				;  |
	CMP $1C				;  | (vert screen boundry)
	ROL $00				;  |
	PLP				;  |
	LDA !14D4,x			;  | 
	ADC #$00			;  |
	LSR $00				;  |
	SBC $1D				;  |
	BEQ ON_SCREEN_Y			;  |
	LDA !186C,x			;  | (vert offscreen)
	ORA SPR_T2,y			;  |
	STA !186C,x			;  |
ON_SCREEN_Y:
	DEY				;  |
	BPL ON_SCREEN_LOOP		; /

	LDY !15EA,x		; get offset to sprite OAM
	LDA !E4,x		; \ 
	SEC			;  | 
	SBC $1A			;  | $00 = sprite x position relative to screen boarder
	STA $00			; / 
	LDA !D8,x		; \ 
	SEC			;  | 
	SBC $1C			;  | $01 = sprite y position relative to screen boarder
	STA $01			; / 
	RTS			; return

INVALID:
	PLA			; \ return from *main gfx routine* subroutine...
	PLA			;  |    ...(not just this subroutine)
	RTS			; /


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SUB_OFF_SCREEN
; This subroutine deals with sprites that have moved off screen
; It is adapted from the subroutine at $01AC0D
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SPR_T12:
	db $40,$B0
SPR_T13:
	db $01,$FF
SPR_T14:
	db $30,$C0,$A0,$C0,$A0,$F0,$60,$90		;bank 1 sizes
	db $30,$C0,$A0,$80,$A0,$40,$60,$B0		;bank 3 sizes
SPR_T15:
	db $01,$FF,$01,$FF,$01,$FF,$01,$FF		;bank 1 sizes
	db $01,$FF,$01,$FF,$01,$00,$01,$FF		;bank 3 sizes

SUB_OFF_SCREEN_X1:
	LDA #$02			; \ entry point of routine determines value of $03
	BRA STORE_03			;  | (table entry to use on horizontal levels)
SUB_OFF_SCREEN_X2:
	LDA #$04			;  | 
	BRA STORE_03			;  |
SUB_OFF_SCREEN_X3:
	LDA #$06			;  |
	BRA STORE_03			;  |
SUB_OFF_SCREEN_X4:
	LDA #$08			;  |
	BRA STORE_03			;  |
SUB_OFF_SCREEN_X5:
	LDA #$0A			;  |
	BRA STORE_03			;  |
SUB_OFF_SCREEN_X6:
	LDA #$0C			;  |
	BRA STORE_03			;  |
SUB_OFF_SCREEN_X7:
	LDA #$0E			;  |
STORE_03:
	STA $03				;  |
	BRA START_SUB			;  |
SUB_OFF_SCREEN_X0:
	STZ $03				; /

START_SUB:
	JSR SUB_IS_OFF_SCREEN	; \ if sprite is not off screen, return
	BEQ RETURN_35		; /
	LDA $5B			; \  goto VERTICAL_LEVEL if vertical level
	AND #$01		; |
	BNE VERTICAL_LEVEL	; /
	LDA !D8,x		; \
	CLC			; | 
	ADC #$50		; | if the sprite has gone off the bottom of the level...
	LDA !14D4,x		; | (if adding 0x50 to the sprite y position would make the high byte >= 2)
	ADC #$00		; | 
	CMP #$02		; | 
	BPL ERASE_SPRITE	; /    ...erase the sprite
	LDA !167A,x		; \ if "process offscreen" flag is set, return
	AND #$04		; |
	BNE RETURN_35		; /
	LDA $13			;A:8A00 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdiZcHC:0756 VC:176 00 FL:205
	AND #$01		;A:8A01 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdizcHC:0780 VC:176 00 FL:205
	ORA $03			;A:8A01 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdizcHC:0796 VC:176 00 FL:205
	STA $01			;A:8A01 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdizcHC:0820 VC:176 00 FL:205
	TAY			;A:8A01 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdizcHC:0844 VC:176 00 FL:205
	LDA $1A			;A:8A01 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdizcHC:0858 VC:176 00 FL:205
	CLC			;A:8A00 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdiZcHC:0882 VC:176 00 FL:205
	ADC SPR_T14,y		;A:8A00 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdiZcHC:0896 VC:176 00 FL:205
	ROL $00			;A:8AC0 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:eNvMXdizcHC:0928 VC:176 00 FL:205
	CMP !E4,x		;A:8AC0 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:eNvMXdizCHC:0966 VC:176 00 FL:205
	PHP			;A:8AC0 X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdizCHC:0996 VC:176 00 FL:205
	LDA $1B			;A:8AC0 X:0009 Y:0001 D:0000 DB:01 S:01F0 P:envMXdizCHC:1018 VC:176 00 FL:205
	LSR $00			;A:8A00 X:0009 Y:0001 D:0000 DB:01 S:01F0 P:envMXdiZCHC:1042 VC:176 00 FL:205
	ADC SPR_T15,y		;A:8A00 X:0009 Y:0001 D:0000 DB:01 S:01F0 P:envMXdizcHC:1080 VC:176 00 FL:205
	PLP			;A:8AFF X:0009 Y:0001 D:0000 DB:01 S:01F0 P:eNvMXdizcHC:1112 VC:176 00 FL:205
	SBC !14E0,x		;A:8AFF X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdizCHC:1140 VC:176 00 FL:205
	STA $00			;A:8AFF X:0009 Y:0001 D:0000 DB:01 S:01F1 P:eNvMXdizCHC:1172 VC:176 00 FL:205
	LSR $01			;A:8AFF X:0009 Y:0001 D:0000 DB:01 S:01F1 P:eNvMXdizCHC:1196 VC:176 00 FL:205
	BCC SPR_L31		;A:8AFF X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdiZCHC:1234 VC:176 00 FL:205
	EOR #$80		;A:8AFF X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdiZCHC:1250 VC:176 00 FL:205
	STA $00			;A:8A7F X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdizCHC:1266 VC:176 00 FL:205
SPR_L31:
	LDA $00			;A:8A7F X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdizCHC:1290 VC:176 00 FL:205
	BPL RETURN_35		;A:8A7F X:0009 Y:0001 D:0000 DB:01 S:01F1 P:envMXdizCHC:1314 VC:176 00 FL:205
ERASE_SPRITE:
	LDA !14C8,x		; \ if sprite status < 8, permanently erase sprite
	CMP #$08		; |
	BCC KILL_SPRITE		; /
	LDY !161A,x		;A:FF08 X:0007 Y:0001 D:0000 DB:01 S:01F3 P:envMXdiZCHC:1108 VC:059 00 FL:2878
	CPY #$FF		;A:FF08 X:0007 Y:0000 D:0000 DB:01 S:01F3 P:envMXdiZCHC:1140 VC:059 00 FL:2878
	BEQ KILL_SPRITE		;A:FF08 X:0007 Y:0000 D:0000 DB:01 S:01F3 P:envMXdizcHC:1156 VC:059 00 FL:2878
	LDA #$00		;A:FF08 X:0007 Y:0000 D:0000 DB:01 S:01F3 P:envMXdizcHC:1172 VC:059 00 FL:2878
	STA $1938|!Base2,y	;A:FF00 X:0007 Y:0000 D:0000 DB:01 S:01F3 P:envMXdiZcHC:1188 VC:059 00 FL:2878
KILL_SPRITE:
	STZ !14C8,x		; erase sprite
RETURN_35:
	RTS			; return

VERTICAL_LEVEL:
	LDA !167A,x		; \ if "process offscreen" flag is set, return
	AND #$04		; |
	BNE RETURN_35		; /
	LDA $13			; \
	LSR A			; |
	BCS RETURN_35		; /
	LDA !E4,x		; \
	CMP #$00		;  | if the sprite has gone off the side of the level...
	LDA !14E0,x		;  |
	SBC #$00		;  |
	CMP #$02		;  |
	BCS ERASE_SPRITE	; /  ...erase the sprite
	LDA $13			;A:0000 X:0009 Y:00E4 D:0000 DB:01 S:01F3 P:eNvMXdizcHC:1218 VC:250 00 FL:5379
	LSR A			;A:0016 X:0009 Y:00E4 D:0000 DB:01 S:01F3 P:envMXdizcHC:1242 VC:250 00 FL:5379
	AND #$01		;A:000B X:0009 Y:00E4 D:0000 DB:01 S:01F3 P:envMXdizcHC:1256 VC:250 00 FL:5379
	STA $01			;A:0001 X:0009 Y:00E4 D:0000 DB:01 S:01F3 P:envMXdizcHC:1272 VC:250 00 FL:5379
	TAY			;A:0001 X:0009 Y:00E4 D:0000 DB:01 S:01F3 P:envMXdizcHC:1296 VC:250 00 FL:5379
	LDA $1C			;A:001A X:0009 Y:0001 D:0000 DB:01 S:01F3 P:eNvMXdizcHC:0052 VC:251 00 FL:5379
	CLC			;A:00BD X:0009 Y:0001 D:0000 DB:01 S:01F3 P:eNvMXdizcHC:0076 VC:251 00 FL:5379
	ADC SPR_T12,y		;A:00BD X:0009 Y:0001 D:0000 DB:01 S:01F3 P:eNvMXdizcHC:0090 VC:251 00 FL:5379
	ROL $00			;A:006D X:0009 Y:0001 D:0000 DB:01 S:01F3 P:enVMXdizCHC:0122 VC:251 00 FL:5379
	CMP !D8,x		;A:006D X:0009 Y:0001 D:0000 DB:01 S:01F3 P:eNVMXdizcHC:0160 VC:251 00 FL:5379
	PHP			;A:006D X:0009 Y:0001 D:0000 DB:01 S:01F3 P:eNVMXdizcHC:0190 VC:251 00 FL:5379
	LDA.w $001D		;A:006D X:0009 Y:0001 D:0000 DB:01 S:01F2 P:eNVMXdizcHC:0212 VC:251 00 FL:5379
	LSR $00			;A:0000 X:0009 Y:0001 D:0000 DB:01 S:01F2 P:enVMXdiZcHC:0244 VC:251 00 FL:5379
	ADC SPR_T13,y		;A:0000 X:0009 Y:0001 D:0000 DB:01 S:01F2 P:enVMXdizCHC:0282 VC:251 00 FL:5379
	PLP			;A:0000 X:0009 Y:0001 D:0000 DB:01 S:01F2 P:envMXdiZCHC:0314 VC:251 00 FL:5379
	SBC !14D4,x		;A:0000 X:0009 Y:0001 D:0000 DB:01 S:01F3 P:eNVMXdizcHC:0342 VC:251 00 FL:5379
	STA $00			;A:00FF X:0009 Y:0001 D:0000 DB:01 S:01F3 P:eNvMXdizcHC:0374 VC:251 00 FL:5379
	LDY $01			;A:00FF X:0009 Y:0001 D:0000 DB:01 S:01F3 P:eNvMXdizcHC:0398 VC:251 00 FL:5379
	BEQ SPR_L38		;A:00FF X:0009 Y:0001 D:0000 DB:01 S:01F3 P:envMXdizcHC:0422 VC:251 00 FL:5379
	EOR #$80		;A:00FF X:0009 Y:0001 D:0000 DB:01 S:01F3 P:envMXdizcHC:0438 VC:251 00 FL:5379
	STA $00			;A:007F X:0009 Y:0001 D:0000 DB:01 S:01F3 P:envMXdizcHC:0454 VC:251 00 FL:5379
SPR_L38:
	LDA $00			;A:007F X:0009 Y:0001 D:0000 DB:01 S:01F3 P:envMXdizcHC:0478 VC:251 00 FL:5379
	BPL RETURN_35		;A:007F X:0009 Y:0001 D:0000 DB:01 S:01F3 P:envMXdizcHC:0502 VC:251 00 FL:5379
	BMI ERASE_SPRITE	;A:8AFF X:0002 Y:0000 D:0000 DB:01 S:01F3 P:eNvMXdizcHC:0704 VC:184 00 FL:5490

SUB_IS_OFF_SCREEN:
	LDA !15A0,x		; \ if sprite is on screen, accumulator = 0 
	ORA !186C,x		; |
	RTS			; / return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;My own routines here.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MainSpriteClipA:
;Get the main sprite's hitbox in A. NOTE: hitbox is actually 12x12 centered.
	LDA !E4,x	;\X position
	CLC		;|
	ADC #$02	;|
	STA $04		;|
	LDA !14E0,x	;|
	ADC #$00	;|
	STA $0A		;/
	LDA !D8,x	;\Y position
	CLC		;|
	ADC #$02	;|
	STA $05		;|
	LDA !14D4,x	;|
	ADC #$00	;|
	STA $0B		;/
	LDA #$0C	;\Hitbox width and height
	STA $06		;|
	STA $07		;/
	RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ExtSprFireballClipB:
;Gets the clipping of an extended sprite's hitbox into B.
	LDA $171F|!Base2,y	;\X position
	STA $00			;|
	LDA $1733|!Base2,y	;|
	STA $08			;/
	LDA $1715|!Base2,y	;\Y position
	STA $01			;|
	LDA $1729|!Base2,y	;|
	STA $09			;/

	.DifferentSize		
	LDA $170B|!Base2,y		;\Determine the shape of hitbox
	CMP #$05		;|depending on its extended sprite number
	BEQ ..PlayerFireball	;|
	CMP #$11		;|
	BEQ ..YoshiFireball	;|
	BRA .done		;/

	..PlayerFireball
	LDA #$08
	BRA ..SetSize

	..YoshiFireball
	LDA #$10

	..SetSize
	STA $02
	STA $03

	.done
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BounceSprClipB:
;Gets the clipping of a bounce sprite hitbox into B
	LDA $16A5|!Base2,y	;\X position
	STA $00			;|
	LDA $16AD|!Base2,y	;|
	STA $08			;/
	LDA $16A1|!Base2,y	;\Y position
	STA $01			;|
	LDA $16A9|!Base2,y	;|
	STA $09			;/

	LDA #$10	;\#$10 by #$10 (16x16) hitbox.
	STA $02		;|
	STA $03		;/
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CarryableKickedClipB:
;Gets the clipping of most "16x16" (actually 14x14?) carryable/kicked sprites
	LDA !14E0,y	;\High byte x pos
	XBA		;/
	LDA !E4,y	;>low byte x pos (LDA $xx,y does not exist).
	REP #$20	;\Add by #$0002 towards the right
	CLC		;|
	ADC #$0002	;|
	SEP #$20	;/
	STA $00		;>Store to low byte x position hitbox B
	XBA		;\Same for high byte
	STA $08		;/

	LDA !14D4,y	;\High byte y pos
	XBA		;/
	LDA !D8,y	;>low byte y pos (LDA $xx,y does not exist).
	REP #$20	;\Add by #$0002 downwards
	CLC		;|
	ADC #$0002	;|
	SEP #$20	;/
	STA $01		;>Store that to y position hitbox B
	XBA		;\Same for high byte
	STA $09		;/

	LDA #$0E	;\#$0E by #$0E (14x14) hitbox
	STA $02		;|
	STA $03		;/
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CapeClipB:
;Gets the clipping of a cape spin. I highly recommend using
;"Cape Layer 2 Position Fix" from the patch section to prevent a bug where
;the cape's interaction would "escape from the player" and flies off from
;the player in layer 2 levels during a freeze (setting $7E009D).
;
;output:
;Carry = clear if non-existent (like not doing a cape spin at all).
	LDA $13E8|!Base2	;\If interact flag is off, no hitbox.
	BEQ .NoCapeHitbox	;/
	LDA !15D0,x		;>If current sprite is about to be eaten...
	ORA !154C,x		;>Or if contact is disabled
	ORA !1FE2,x		;>Or if timer of no interaction via cape is running
	BNE .NoCapeHitbox	;>Then mark as no hitbox
	LDA !1632,x		;>Sprite scenery flag
	PHY			;>Preserve Y
	LDA $74			;\If not climbing, skip
	BEQ .NotClimbing	;/
	EOR #$01		;>Invert climbing flag?

	.NotClimbing
	PLY
	EOR $13F9|!Base2	;>Flip player behind layers flag
	BNE .NoCapeHitbox	;>If sprite and mario not on the same side of net, no hitbox.
	;JSL $03B69F		;>Get contact for current sprite (not needed)

	.GetCapeHitbox
	LDA $13E9|!Base2	;\From the spinning cape's x position, move 2 pixels left...
	SEC			;|
	SBC #$02		;/
	STA $00			;>...And set hitbox x position
	LDA $13EA|!Base2	;\Same thing but high byte x position
	SBC #$00		;|
	STA $08			;/
	LDA #$14		;\Hitbox width (#$14 (20) pixels wide)
	STA $02			;/
	LDA $13EB|!Base2	;\Y position of the top of the cape's hitbox
	STA $01			;|
	LDA $13EC|!Base2	;|
	STA $09			;/
	LDA #$10		;\Hitbox height (#$10 (16) pixels tall)
	STA $03			;/
	SEC			;>Set carry.
	RTS

	.NoCapeHitbox
	CLC			;>Clear carry.
	RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SpawnSmokeByExtSpr:
;This spawns smoke on the position the extended sprite is on.
;Input:
;X = extended sprite slot number
	LDY.b #$04-1

	.Loop
	LDA $17C0|!Base2,y		;\Check if slot is currently
	BEQ ..SlotFound
	JMP ..NextSlot		;/reserved.

	..SlotFound
	..OffScreenCheck
	...Horizontal
	LDA $1733|!Base2,x	;\extended sprite's X position in 16-bit...
	XBA			;|
	LDA $171F|!Base2,x	;/
	REP #$20		;
	PHA			;>Save X position
	SEP #$20		;
	LDA $170B|!Base2,x	;\Check what sprite for proper centering
	CMP #$05		;/
	BEQ ....EightByEightSpr
	;CMP #$11
	;BEQ ....SixteenBySixteenSpr

	....SixteenBySixteenSpr
	REP #$20
	PLA			;>Get X position back
	SEC			;\Make it centered with fireball sprite
	SBC #$0004		;/
	BRA ...XPosScrn		;>Don't PLA again (crashes due to push 1 byte, and pull 2 bytes; a mismatch).

	....EightByEightSpr
	REP #$20
	PLA			;>Get X position back

	...XPosScrn
	SEC			;\Now X position on-screen (distance between extsprite and left edge of screen,
	SBC $1462|!Base2	;/signed)
	CMP #$0100		;\If >= (unsigned) than #$0100 (the width of the screen)
	SEP #$20		;|
	BCS .Done		;/don't draw smoke

	...Vertical
	LDA $1729|!Base2,x	;\extended sprite's Y position in 16-bit...
	XBA			;|
	LDA $1715|!Base2,x	;/
	REP #$20		;
	PHA			;>Save Y position
	SEP #$20		;
	LDA $170B|!Base2,x	;\Check what sprite for proper centering
	CMP #$05		;/
	BEQ ....EightByEightSpr
	;CMP #$11
	;BEQ ....SixteenBySixteenSpr

	....SixteenBySixteenSpr
	REP #$20
	PLA			;>Get X position back
	SEC			;\Make it centered with fireball sprite
	SBC #$0004		;/
	BRA ...YPosScrn		;>Don't PLA again (crashes due to push 1 byte, and pull 2 bytes; a mismatch).

	....EightByEightSpr
	REP #$20
	PLA

	...YPosScrn
	SEC			;\...Now Y position on-screen
	SBC $1464|!Base2	;/
	CMP #$0100		;\If >= (unsigned) than #$0100 (the height of the screen
	SEP #$20		;|with 2 blocks added below)...
	BCS .Done		;/Don't draw smoke

	LDA #$01		;\Set smoke sprite number
	STA $17C0|!Base2,y	;/
	LDA #$1B		;\Set smoke existence timer
	STA $17CC|!Base2,y	;/

	..SetPos
	LDA $170B|!Base2,x		;\Check what sprite for proper centering
	CMP #$05			;/
	BEQ ...EightByEightSpr
	;CMP #$11
	;BEQ ...SixteenBySixteenSpr

	...EightByEightSpr
	LDA $171F|!Base2,x	;\Set X position
	SEC			;|
	SBC #$04		;|
	STA $17C8|!Base2,y	;/
	LDA $1715|!Base2,x	;\Set Y position
	SEC			;|
	SBC #$04		;|
	STA $17C4|!Base2,y	;/
	;BRA .Done
	RTS

	...SixteenBySixteenSpr
	LDA $171F|!Base2,x	;\Set X position
	STA $17C8|!Base2,y	;/
	LDA $1715|!Base2,x	;\Set Y position
	STA $17C4|!Base2,y	;/
	;BRA .Done		;>Don't write to all other slots for a single extsprite.
	RTS

	..NextSlot
	DEY
	BMI .Done
	JMP .Loop

	.Done
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
StompSounds:
	db $00,$13,$14,$15,$16,$17,$18,$19 ;>The SFX for each pitch.

ConsecutiveStomps:
;A routine that each time you jump on an enemy without touching the ground
;displays (increasing) points as well as increasing the consecutive stomps
;counter ($1697).
	PHY
	LDA $1697|!Base2
	CLC			;\Add by Consecutive enemies killed by a sprite (how kicked shells
	ADC !1626,x		;/continue the counter if you stop it after killing many enemies)
	INC $1697|!Base2	;>Increase it again (so it increase by a value that is AT LEAST 1)(won't write to A).
	TAY			;>Transfer it to Y for each sounds and score.
	INY			;>Don't know why nintendo would increase it again for some reason...
	CPY #$08		;\If after the last sound pitch (and a score of 8000),
	BCS .NoSound		;/replace with 1-up.
	LDA StompSounds,y	;\Play stomp sounds with different pitches
	STA $1DF9|!Base2	;/depending on the consecutive stomp counter.

	.NoSound
	TYA			;>Transfer back to A
	CMP #$08		;\Now I know why it uses INY above, basicaly so that the original value would make 
	BCC .NoReset		;/this assume always #$08 or #$07. Here, this caps to prevent 256 stomps overflow.
	LDA #$08		;>Load maximum value

	.NoReset
	PHX
	JSL $02ACE5		;>Give points (200, 400, 800, 1000, 2000, 4000, 8000, 1-up.)
	PLX
	PLY
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SpinjumpKillSprite:
;Makes sprite die as if they were spinjumped.
;NOTE: ALL extended sprites are killable by cape, even the 4 stars.

	LDA #$04		;\Kill the sprite as if spin-jumping it.
	STA !14C8,X		;|
	LDA #$1F		;|
	STA !1540,X		;|
	PHY			;|>Y was used for other extended sprite
	JSL $07FC3B		;|
	PLY			;|>Restore it
	LDA #$08		;|
	STA $1DF9|!Base2	;/
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Capped healing routine.
;
;Input:
;-$00-$01 is the amount of HP recovered. Only $00
; would be used should two-byte HP was set to 1
; byte.
;Output:
;-Sprite's current HP recovered, capped at max.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Heal:
	.StoreHealedValue
	if !Setting_SpriteHP_TwoByteHP != 0 ;>maths are different depending if you wanted 2-byte HP or not.
		LDA !Freeram_SprTbl_CurrHPLow,x		;\low byte
		CLC					;|
		ADC $00					;|>ADC sets carry if unsigned overflow happens
		STA $00					;/
		LDA !Freeram_SprTbl_CurrHPHi,x		;\high byte
		ADC $01					;|>ADC adds an additional 1 when overflowed
		STA $01					;/
		BCS .Maxed				;>if exceeds 65535

		.CompareWithMaxHP
		LDA $00					;\CMP is like SBC, should underflow happens, carry is clear
		CMP !Freeram_SprTbl_MaxHPLow,x		;/HealedHPLow - MaxHPLow: carry is cleared if MaxHPLow is bigger
		LDA $01					;\should the above carry is clear, subtract by an additional 1 (4-5 becomes 4-6; borrow)
		SBC !Freeram_SprTbl_MaxHPHi,x		;/HealedHPHi - MaxHPHi: carry is cleared if MaxHPHi is bigger
		BCC .ValidHP				;>if carry clear (below/equal to max HP), set current HP to healed HP amount.

		.Maxed
		LDA !Freeram_SprTbl_MaxHPLow,x		;\Set HP to max when carry is set (CurrentHP - MaxHP = positive value)
		STA !Freeram_SprTbl_CurrHPLow,x		;|
		LDA !Freeram_SprTbl_MaxHPHi,x		;|
		STA !Freeram_SprTbl_CurrHPHi,x		;/
		RTS

		.ValidHP
		LDA $00					;\Set HP to the amount of HP after healed.
		STA !Freeram_SprTbl_CurrHPLow,x		;|
		LDA $01					;|
		STA !Freeram_SprTbl_CurrHPHi,x		;/
	else ;>when using single-byte HP
		LDA !Freeram_SprTbl_CurrHPLow,x		;\get HP after being healed
		CLC					;|
		ADC $00					;/
		BCS .Maxed				;>in case HP goes past 255 when max HP is 255.
		CMP !Freeram_SprTbl_MaxHPLow,x		;\if over the max, cap it also.
		BCS .Maxed				;/
		BRA .ValidHP
		
		.Maxed
		LDA !Freeram_SprTbl_MaxHPLow,x
		
		.ValidHP
		STA !Freeram_SprTbl_CurrHPLow,x
	endif
	RTS