;Freeram
 if !sa1 == 0
	!Freeram_SpriteHP_Data		= $7FACC4 ;>normal ROM address
 else
	!Freeram_SpriteHP_Data		= $400110 ;>sa-1 address (banks $40/$41)
 endif
 ;^[X bytes total], contains HP data, see Freeram stuff for the format
 ; (ordered from the source address).
 ;
 ; BytesUsed = 1 + (SprslotSize*2) + (SprslotSize * EnabledableTable)
 ;
 ;Where:
 ; *SprslotSize = 12 for nromal ROM, 22 for SA-1
 ; *EnabledableTable = the *NUMBER OF* sprite tables that are disable-able
 ;  being enabled (in the readme, it is the box table with highlighted red
 ;  rows).

;Settings
 !Setting_SpriteHP_TwoByteHP		= 1
 ;^0 = 8-bit HP (HP up to 255).
 ;^1 = 16-bit HP (up to 65535).
 ; This is if you want to save memory if you're using less than or equal to 255 HP.
 ;NOTE: 16-bit HP does NOT apply to SMW bosses and enemies, only custom sprites.
 ;This is due to the fact that sprites are hard-coded to use an incrementing hit
 ;counter stored as a single byte instead.

 !Setting_SpriteHP_DisplayNumerical	= 2
 ;^0 = no, 1 = current only, 2 = current/max.

 !Setting_EnemyHPMaxDigits		= 4
 ;^Number of digits at max the enemy has. You probably wouldn't set it above
 ; 3 for 8-bit HP and 5 for 2-byte HP. This define is useful if you don't want
 ; unnecessary blank tile that cannot be used for other things when having lower
 ; number of digits.

 !Setting_EnemyHP_ExcessDigitProt		= 1
 ;^0 = off, 1 = on. This is a failsafe protection and indicator against a glitch
 ; where should HP and/or max HP were to have more digits than !Setting_EnemyHPMaxDigits,
 ; would display "-" across the line (actually if the total number of characters
 ; were to exceed.). Useful in case if you accidentally have a code that have the
 ; HP value exceed the digit limit. This is an option to turn off in case if you're
 ; running low on ROM space.
 
 ;Note that if you set the number of digits (!Setting_EnemyHPMaxDigits) equal or higher
 ;than 3 for 8-bit HP or equal to 5 for 16-bit, this won't be included because exceeding
 ;those number of digits in decimal is impossible (in 8-bit, 255 is the max unsigned integer
 ;whereas the maximum 3 digit number in decimal is 999. In 16-bit, 65535 is the max number
 ;with the maximum 5 digit decimal number being 99999). Again, you wouldn't have the number
 ;of digits above 3 or 5, that would be foolish.

 !Setting_EnemyHPAlignDigits		= 2
 ;0 = allow leading spaces (digit place values are fixed)
 ;1 = left align (positions the character (numbers and "/") to the left as much
 ;    as possible), no leading spaces before digits.
 ;2 = right align (to the right as possible).  No leading spaces before digits.
 ;
 ;do note that the number of digits extends the 8x8 area RIGHTWARDS,
 ;therefore setting !Setting_EnemyHPMaxDigits does not move the left part of the
 ;character table.
 ;
 ;Keep in mind that the tiles being written to (whether if there is a blank tile
 ;or digits) are ALWAYS written to, for example: a 5 digit HP display showing
 ;current and max HP as 1/10000 could be [1/10000****] or [****1/10000] where
 ;* is a blank tile written every frame. This is there to prevent frozen suspended
 ;tiles from showing when a number lose or gains a digit. If you're unsure, set
 ;!EnemyHPBlankTile to any tile number that doesn't camouflage with the surrounding
 ;8x8 tiles of the layer 3 HUD.

 !Setting_SpriteHP_BarAnimation		= 1
 ;^0 = bar only shows current HP, and instantly updates.
 ; 1 = bar have a transparent, sliding, or filling animation.
 ; This is if you want to save memory if you want a simple bar.
 ; When set to 0, disables the record effect RAM
 ; (!Freeram_SprTbl_RecordEfft and Freeram_SprTbl_RecordEffTmr)

;Scratch RAM 
 if !sa1 == 0
  !Scratchram_CharacterTileTable	= $7F844A
 else
  !Scratchram_CharacterTileTable	= $400198
 endif
 ;^the table that each byte holds a character. This is used
 ; to store digits to move them so that they are left or right-aligned.
 ; Not used if:
 ; -!Setting_EnemyHPAlignDigits and/or !Setting_SpriteHP_DisplayNumerical set to 0
 ;  (no digits to display at all).
 ; -!Setting_EnemyHPAlignDigits set to 2 (right-aligned) and
 ;  !Setting_SpriteHP_DisplayNumerical to 1 (number as current HP without max HP)

;Tile stuff
 if !sa1 == 0
  !EnemyHPNumericalPosition		= $7FA024
 else
  !EnemyHPNumericalPosition		= $404024
 endif
 ;^Position of the numbers to display HP as numbers.
 
 if !sa1 == 0
  !EnemyHPGraphicalBarPos		= $7FA064
 else
  !EnemyHPGraphicalBarPos		= $404064
 endif
 ;^Position of the bar to display HP as percent.
 ;For editing things like the length of the bar,
 ;number of pieces in each 8x8 tile, refer to
 ;"GraphicalBarDefines.asm".

 !EnemyHPBlankTile			= $FC
 ;^Blank tile used when the HP meter isn't present. This is here in case if you
 ; need to test if a tile is written $FC every frame vs static $FC written that
 ; can be used for other counters. This is also helpful if your status bar have
 ; an opaque background and need just a "blank background" tile.

 !EnemyHPTilePrefixMax			= $48
 ;^The tile number to prefix the max HP ("/")

;How the bar represents change of HP

 !EnemyHPBarFillUpSpd			= $00
 ;^Speed that the bar fills up. Only use these values:
 ;$00,$01,$03,$07$,$0F,$1F,$3F or $7F. Lower values = faster
 
 !EnemyHPBarFillUpSpdPerFrame		= 0
 ;^How many pieces in the bar filled per frame. This overrides
 ;!EnemyHPBarFillUpSpd when 2+. Higher = faster filling animation.

 !EnemyHPBarFillDrainSpd		= $01
 ;^How fast the record effect goes down after the record freeze timer hits
 ; zero. Same rules as !EnemyHPBarFillUpSpd.
 
 !EnemyHPBarEmptyingSpdPerFrame		= 2
 ;^How many pieces in the bar drained per frame. This overrides
 ;!EnemyHPBarFillDrainSpd when 2+. Higher = faster draining animation.
 ;

 !EnemyHPBarRecordDelay			= 30
 ;^How many frames the record effect (transparent effect) hangs
 ; before shrinking down to current HP, up to 255 is allowed.
 ; Set to 0 to disable (will also disable !Freeram_SprTbl_RecordEffTmr
 ; from being used,). Remember, the game runs 60 FPS.

 !Setting_SpriteHP_ShowTransperent	= 1
 ;^0 = only show sliding animation, 1 = show damage as transparent.
 ; If only show sliding animation, better to disable !EnemyHPBarRecordDelay
 ; as well.

;SFX
 !EnemyHPBarSfxNumb		= $23		;>$00 = no sfx write.
 !EnemyHPBarSfxRamPort		= $1DFC		;>Auto-converted to SA-1.

;Graphical bar defaults
 ;Redefineable stuff (often preset settings):
  !Default_MiddleLength                = 10            ;>30 = screen-wide (30 middles + 2 end tiles = 32, all 8x8 tile row in the screen's width)

  ;if !sa1 == 0
  ; !GraphicalBarPos                     = $7FA000      ;>Status bar RAM data. 
  ;else
  ; !GraphicalBarPos                     = $404000      ;>Status bar RAM data.
  ;endif
  ;^not used, use !EnemyHPGraphicalBarPos in "EnemyHP.asm" instead.
 
  !Default_LeftPieces                  = 3             ;\These will by default, set the RAM for the pieces for each section
  !Default_MiddlePieces                = 8             ;|
  !Default_RightPieces                 = 3             ;/

  !Leftwards                           = 1
  ;^Have the bar fill leftwards. Note that end tiles are also
  ; mirrored
 
  !Setting_EnemyHP_BarAvoidRoundToZero	= 1
  ;^Display 1/max in the bar should the percent calculation
  ; tries to display less than 1 piece but not 0.


 ;Don't touch, these are used for loops to write to the status bar.
  !GraphiBar_LeftTileExist = 0
  !GraphiBar_MiddleTileExist = 0
  !GraphiBar_RightTileExist = 0
  if !Default_LeftPieces != 0
   !GraphiBar_LeftTileExist = 1
  endif
  if !Default_MiddlePieces != 0 && !Default_MiddleLength != 0
   !GraphiBar_MiddleTileExist = 1
  endif
  if !Default_RightPieces != 0
   !GraphiBar_RightTileExist = 1
  endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Sprite tool RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
!Ram_CustSprBit =	!7FAB10	;\just in case if there is a sprite tool that
!Ram_CustSprNum =	!7FAB9E	;/uses different ram address or SA-1.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Dummy JSLs
;
;This is needed so that sprites uses the built-in routine
;provided by the patch. Access using JSL.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
!Addr_DummyJSLs				= $128000
 ;Address to place your dummy JSL to jump to here. (It's
 ;a list of JML (4 bytes each) to a subroutine. To be
 ;added to an unused freespace area. Be careful not to
 ;patch this, then change this address to another location,
 ;then patch this again.
 ;
 ;If you're using custom sprites, make sure you use the
 ;defines on the left margin (before the equals sign)
 ;for easy readability.
 ;
 ;Of course, you can move these subroutines to the shared
 ;subroutines patch. Don't forget to include the definitions
 ;file relating to enemy HP. The subroutine call is located
 ;using CTRL+F "org !Addr_DummyJSLs" and the subroutine itself
 ;are the JML labels. Be careful should a !Define could
 ;conflict, so make sure you rename them.

;don't touch these

 !EnemyHP_RatsDisplacement = $00
 if (!Addr_DummyJSLs>>16)&$7F >= $10  ;\If the user selects bank $10 or higher, move the JML
  !EnemyHP_RatsDisplacement = $08     ;|list 8 bytes for the rats tag to be placed.
 endif                                ;/

 ;Position each JML 4 bytes apart:
  if !Setting_SpriteHP_BarAnimation != 0
   !DummyJSL_EnemyHP_RemoveRecordEffect = (!Addr_DummyJSLs+!EnemyHP_RatsDisplacement)
  endif
  !DummyJSL_EnemyHP_LoseHP = (!Addr_DummyJSLs+!EnemyHP_RatsDisplacement)+(!Setting_SpriteHP_BarAnimation*4) ;>this is so that if above disabled, this will take its place.
  !DummyJSL_EnemyHP_DisplayHP = !DummyJSL_EnemyHP_LoseHP+4                                                  ;>Don't use this on a sprite!! This is for uberasm exclusively.
  !DummyJSL_EnemyHP_GetPercentHP = !DummyJSL_EnemyHP_DisplayHP+4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Freeram stuff (maps the tables relative to !Freeram_SpriteHP_Data)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Don't touch these (this allows the table to be gap-less between each table
;when any of them gets disabled)

;although the if statements are redundant here (codes mainly disabled in main patch),
;they're there to prevent user from accidentally making custom sprites use disabled
;RAM.

;Table positioning format:
;!FreeramDefine = $xxxxxx
;!FreeramDefine1 = FreeramDefine + TableSize
;if !ThisTableEnabled != 0
; !FreeramDefine2 = FreeramDefine1 + TableSize
;endif
;!FreeramDefine3  = FreeramDefine1 + TableSize + (TableSize*!ThisTableEnabled)
;                   ^[1]                         ^[2]
;[1] would replace the table that the previously define (!FreeramDefine2) was disabled.
;[2] would place !FreeramDefine3 after the enabled !FreeramDefine2.
;
;-"Exist" is either 0 or 1.
;-"TableSize" is 12 for normal ROM and 22 for SA-1

 !SpriteHPRecordDelayExist = 0
 if !Setting_SpriteHP_BarAnimation != 0 && !EnemyHPBarRecordDelay != 0
  !SpriteHPRecordDelayExist = 1
 endif

 !Freeram_SprHPCurrSlot		=	!Freeram_SpriteHP_Data+0;>current sprite slot

 !Freeram_SprTbl_CurrHPLow	=	!Freeram_SprHPCurrSlot+1
 if !Setting_SpriteHP_TwoByteHP != 0
  !Freeram_SprTbl_CurrHPHi	=	!Freeram_SprTbl_CurrHPLow+!sprite_slots
 endif
 !Freeram_SprTbl_MaxHPLow	=	!Freeram_SprTbl_CurrHPLow+!sprite_slots+(!sprite_slots*!Setting_SpriteHP_TwoByteHP)
 if !Setting_SpriteHP_TwoByteHP != 0
  !Freeram_SprTbl_MaxHPHi	=	!Freeram_SprTbl_MaxHPLow+!sprite_slots
 endif
 if !Setting_SpriteHP_BarAnimation != 0
  !Freeram_SprTbl_RecordEfft	=	!Freeram_SprTbl_MaxHPLow+!sprite_slots+(!sprite_slots*!Setting_SpriteHP_TwoByteHP)
 endif
 if !SpriteHPRecordDelayExist != 0
  !Freeram_SprTbl_RecordEffTmr	=	!Freeram_SprTbl_MaxHPLow+!sprite_slots+(!sprite_slots*!Setting_SpriteHP_TwoByteHP)+(!sprite_slots*!Setting_SpriteHP_BarAnimation)
 endif

;Due to these values used as multiplication to make the table gap-less, the user could cause a calculation to produce tables
;at invalid locations should they pick any number other than 0 or 1.
assert !Setting_SpriteHP_TwoByteHP == 0 || !Setting_SpriteHP_TwoByteHP == 1, "Invalid option for Setting_SpriteHP_TwoByteHP"
assert !Setting_SpriteHP_BarAnimation == 0 || !Setting_SpriteHP_BarAnimation == 1, "Invalid option for Setting_SpriteHP_BarAnimation"
;
;SMW-related defines and settings:
 ;If you want to save space by not using any smw bosses and enemies.
  !ShowHPOnChuck		=	1	;>0 = false, 1 = true. In case if you want boss-only
  !ShowHPOnSmwBosses		=	1	;>0 = false, 1 = true. In case if you're not using ANY smw bosses but custom sprites.

 ;SMW's bosses and enemies. *ONLY* use 1-255, REGARDLESS if you have HP being stored as 8/16-bit via "!Setting_SpriteHP_TwoByteHP".
  !AllChucksFullHP		=	15	;>Chuck's starting HP.
  !AllChucksStompDmg		=	5	;>Damage chucks received by stomping
  !AllChucksFireDmg		=	3	;>Damage from fireballs when ANY SPRITE have "takes 5 fireballs to kill".
  !BigBooBossFullHP		=	3	;>Big Boo Boss's starting HP
  !BigBooBossThrSprDmg		=	1	;>Damage big boo boss takes from thrown sprite
  !WendyLemmyFullHP		=	3	;>Wendy/Lemmy's starting HP
  !WendyLemmyStompDmg		=	1	;>Damage wendy/lemmy received from stomping
  !LudwigMortonRoyFullHP	=	12	;>Ludwig/Morton/Roy's starting HP
  !LudwigMortonRoyStompDmg	=	4	;>Damage Ludwig/Morton/Roy received from stomping
  !LudwigMortonRoyFireDmg	=	1	;>Damage Ludwig/Morton/Roy received from fireballs.