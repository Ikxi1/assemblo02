INCLUDE "hardware.inc"

DEF BRICK_LEFT EQU $05
DEF BRICK_RIGHT EQU $06
DEF BLANK_TILE EQU $08

SECTION "Header", ROM0[$100]

	JP EntryPoint
	
	DS $150 - @, 0 ; Make room for the header
	
EntryPoint:
	; Do not turn the LCD off outside of VBlank

WaitVBlank:
	LD a, [rLY]
	CP 144
	JP c, WaitVBlank
	
	; Turn the LCD off
	LD a, 0
	LD [rLCDC], a
	
	; Copy the tile data
	LD de, Tiles
	LD hl, $9000
	LD bc, TilesEnd - Tiles
	CALL Memcopy

	; Copy the tilemap
	LD de, Tilemap
	LD hl, $9800
	LD bc, TilemapEnd - Tilemap
	CALL Memcopy
	
	; Copy the paddle tile
	LD de, Paddle
	LD hl, $8000
	LD bc, PaddleEnd - Paddle
	CALL Memcopy
	
	; Copy the ball tile
	LD de, Ball
	LD hl, $8010
	LD bc, BallEnd - Ball
	CALL Memcopy
	
	; Clear the Object RAM, because it contains rANDom numbers
	LD a, 0
	LD b, 160
	LD hl, _OAMRAM
ClearOam:
	LD [hli], a
	DEC b
	JP nz, ClearOam

	; load Object into OAM
	LD hl, _OAMRAM
	LD a, 128 + 16
	LD [hli], a
	LD a, 16 + 8
	LD [hli], a
	LD a, 0
	LD [hli], a
	LD [hli], a
	
	; Initialize the paddle sprite in OAM
	LD hl, _OAMRAM
	LD a, 128 + 16
	LD [hli], a
	LD a, 16 + 8
	LD [hli], a
	LD a, 0
	LD [hli], a
	LD [hli], a
	
	; Now initialize the ball sprite
	LD a, 100 + 16
	LD [hli], a
	LD a, 32 + 8
	LD [hli], a
	LD a, 1
	LD [hli], a
	LD a, 0
	LD [hli], a
	; Initialize ball variables
	LD a, 1
	LD [wBallMomentumX], a
	LD a, -1
	LD [wBallMomentumY], a
	
	; Turn the LCD on
	LD a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON ; binary OR to combine the two
	LD [rLCDC], a
	
	; During the first (blank) frame, initialize display registers
	LD a, %11100100
	LD [rBGP], a
	LD a, %11100100
	LD [rOBP0], a
	
	; initialize global variables
	LD a, 0
	; LD [wFrameCounter], a
	LD [wCurKeys], a
	LD [wNewKeys], a
	
Main:
	; Wait until it's NOT VBlank
	LD a, [rLY]
	CP 144
	JP nc, Main
WaitVBlank2:
	LD a, [rLY]
	CP 144
	JP c, WaitVBlank2
	
	; Check the current keys every frames
	; and move left or right
	CALL UpdateKeys
	
	; Ball go zoom
	LD a, [wBallMomentumX]
	LD b, a
	LD a, [_OAMRAM + 5]
	ADD a, b
	LD [_OAMRAM + 5], a

	LD a, [wBallMomentumY]
	LD b, a
	LD a, [_OAMRAM + 4]
	ADD a, b
	LD [_OAMRAM + 4], a

PaddleBounce:
	; First, check if the ball is low enough to bounce off the paddle.
	LD a, [_OAMRAM]
	LD b, a
	LD a, [_OAMRAM + 4]
	ADD a, 5
	CP a, b
	JP nz, PaddleBounceDone ; If the ball isn't at the same Y position as the paddle, it can't bounce.
	; Now let's compare the X positions of the objects to see if they're touching.
	LD a, [_OAMRAM + 5] ; Ball's X position.
	LD b, a
	LD a, [_OAMRAM + 1] ; Paddle's X position.
	SUB a, 8
	CP a, b
	JP nc, PaddleBounceDone
	ADD a, 4 + 12 ; 8 to undo, 16 as the width.
	CP a, b
	JP c, PaddleBounceDone
	LD a, -1
	LD [wBallMomentumY], a
PaddleBounceDone:

BounceOnTop:
	LD a, [_OAMRAM + 4]
	SUB a, 16 + 1
	LD c, a
	LD a, [_OAMRAM + 5]
	SUB a, 8
	LD b, a
	CALL GetTileByPixel ; Ret tile address in hl
	LD a, [hl]
	CALL IsWallTile
	JP nz, BounceOnRight
	call CheckAndHandleBrick
	LD a, 1
	LD [wBallMomentumY], a

BounceOnRight:
	LD a, [_OAMRAM + 4]
	SUB a, 16
	LD c, a
	LD a, [_OAMRAM + 5]
	SUB a, 8 - 7; -1 to look infront, -6 to look at actual position, otherwise into wall
	LD b, a
	CALL GetTileByPixel
	LD a, [hl]
	CALL IsWallTile
	JP nz, BounceOnLeft
	call CheckAndHandleBrick
	LD a, -1
	LD [wBallMomentumX], a

BounceOnLeft:
	LD a, [_OAMRAM + 4]
	SUB a, 16
	LD c, a
	LD a, [_OAMRAM + 5]
	SUB a, 8 + 1 ; no offset, otherwise bounces 1 pixel in front
	LD b, a
	CALL GetTileByPixel
	LD a, [hl]
	CALL IsWallTile
	JP nz, BounceOnBottom
	call CheckAndHandleBrick
	LD a, 1
	LD [wBallMomentumX], a

	; this will need to be fixed, in case the ball hits
	; a brick from above, now it will just phase through
	; and destroy the brick, somehow
BounceOnBottom:
	LD a, [_OAMRAM + 4]
	CP $93
	JP nz, BounceDone
	LD a, -1
	LD [wBallMomentumY], a 
BounceDone:

	; First, check if left
CheckLeft:
	LD a, [wCurKeys]
	AND a, PADF_LEFT
	JP z, CheckRight ; not Z if a = PADF_LEFT
Left:
	; Move the paddle left
	LD a, [_OAMRAM + 1]
	DEC a
	; If at edge, don't move
	CP a, 15
	JP z, Main
	LD [_OAMRAM + 1], a
	JP Main
CheckRight:
	LD a, [wCurKeys]
	AND a, PADF_RIGHT
	JP z, Main
Right:
	; Move right
	LD a, [_OAMRAM + 1]
	INC a
	; If at edge, don't move
	CP a, 105
	JP z, Main
	LD [_OAMRAM + 1], a
	JP Main

; Copy bytes from one area to another.
; @param de: Source
; @param hl: Destination
; @param bc: Length
Memcopy:
	LD a, [de]
	LD [hli], a
	INC de
	DEC bc
	LD a, b
	OR a, c
	JP nz, Memcopy
	RET

; Read input AND write it to variables
; No outside src or dest
UpdateKeys:
	; Poll half the controller
	LD a, P1F_GET_BTN
	CALL .onenibble
	LD b, a ; B7-4 = 1; B3-0 = unpressed buttons
	
	; Poll the other half
	LD a, P1F_GET_DPAD
	CALL .onenibble
	SWAP a ; A3-0 = unpressed directions; A7-4 = 1
	XOR a, b ; A = pressed buttons + directions
	LD b, a ; B = pressed buttons + directions
	
	; AND release the controller
	LD a, P1F_GET_NONE
	LDh [rP1], a
	
	; Combine with previous wCurKeys to make wNewKeys
	LD a, [wCurKeys]
	XOR a, b ; A = keys that changed state
	AND a, b ; A = keys that changed to pressed
	LD [wNewKeys], a
	LD a, b
	LD [wCurKeys], a
	RET

.onenibble
	LDH [rP1], a ; switch the key matrix
	CALL .knownret ; burn 10 cycles CALLing a known ret
	LDH a, [rP1] ; ignore value while waiting for the key matrix to settle
	LDH a, [rP1]
	LDH a, [rP1] ; this read counts
	OR a, $F0 ; A7-4 = 1; A3-0 = unpressed keys
.knownret
	RET ; This return works for burning cycles AND
		; it also works as the return for .onenibble

; Convert a pixel position to a tilemap address
; hl = $9800 + X + Y * 32
; @param b: X
; @param c: Y
; @return hl: tile address
GetTileByPixel:
	; First, we need to divide by 8 to convert a pixel position to a tile position.
	; After this we want to multiply the Y position by 32.
	; These operations effectively cancel out so we only need to mask the Y value.
	LD a, c
	AND a, %11111000
	LD l, a
	LD h, 0
	; Now we have the position * 8 in hl
	ADD hl, hl ; position * 16
	ADD hl, hl ; position * 32
	; Convert the X position to an offset.
	LD a, b
	SRL a ; a / 2
	SRL a ; a / 4
	SRL a ; a / 8
	; Add the two offsets together.
	ADD a, l
	LD l, a
	ADC a, h
	SUB a, l
	LD h, a
	; Add the offset to the tilemap's base address, and we are done!
	LD bc, $9800
	ADD hl, bc
	RET

; @param a: tile ID
; @return z: set if a is a wall.
IsWallTile:
	CP a, $00
	RET z
	CP a, $01
	RET z
	CP a, $02
	RET z
	CP a, $04
	RET z
	CP a, $05
	RET z
	CP a, $06
	RET z
	CP a, $07
	RET

; Checks if a brick was collided with and breaks it if possible.
; @param hl: address of tile.
CheckAndHandleBrick:
	LD a, [hl]
	CP a, BRICK_LEFT
	JR nz, CheckAndHandleBrickRight
	; Break a brick from the left side.
	LD [hl], BLANK_TILE
	INC hl
	LD [hl], BLANK_TILE
CheckAndHandleBrickRight:
	CP a, BRICK_RIGHT
	RET nz
	; Break a brick from the right side.
	LD [hl], BLANK_TILE
	DEC hl
	LD [hl], BLANK_TILE
	RET


SECTION "Tile data", ROM0

Tiles:
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322222
	dw `33322222
	dw `33322222
	dw `33322211
	dw `33322211
	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111
	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222333
	dw `22222333
	dw `22222333
	dw `11222333
	dw `11222333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `22222222
	dw `20000000
	dw `20111111
	dw `20111111
	dw `20111111
	dw `20111111
	dw `22222222
	dw `33333333
	dw `22222223
	dw `00000023
	dw `11111123
	dw `11111123
	dw `11111123
	dw `11111123
	dw `22222223
	dw `33333333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `11001100
	dw `11111111
	dw `11111111
	dw `21212121
	dw `22222222
	dw `22322232
	dw `23232323
	dw `33333333
	; Logo
	; First row left to right
	dw `00000000
	dw `03333330
	dw `03333330
	dw `03333302
	dw `03333013
	dw `03330121
	dw `03330103
	dw `03330333
	
	dw `00000000
	dw `31201203
	dw `22201303
	dw `22201303
	dw `22101303
	dw `22001303
	dw `22011303
	dw `23311303
	
	dw `00000000
	dw `02102213
	dw `03102222
	dw `03102222
	dw `03101222
	dw `03100222
	dw `03110022
	dw `03110332
	
	dw `00000000
	dw `03333330
	dw `03333330
	dw `20333330
	dw `30333330
	dw `30333330
	dw `23003330
	dw `33303330
	; Second row
	dw `03330300
	dw `03333030
	dw `03330311
	dw `03303111
	dw `03303331
	dw `03300210
	dw `03330300
	dw `03302100
	
	dw `30311300
	dw `00313333
	dw `00000000
	dw `10000012
	dw `00000121
	dw `00000220
	dw `00200210
	dw `00220200
	
	dw `03110303
	dw `33113300
	dw `00000000
	dw `00000000
	dw `00000001
	dw `00000000
	dw `00000000
	dw `00000000
	
	dw `00303330
	dw `03033330
	dw `11203330
	dw `11120330
	dw `13330330
	dw `12300330
	dw `11203330
	dw `01130330
	; Third tow
	dw `03303000
	dw `03021001
	dw `03030001
	dw `00210000
	dw `00200003
	dw `00300003
	dw `00300000
	dw `00300200
	
	dw `00020202
	dw `33000002
	dw `33000000
	dw `32000000
	dw `32000000
	dw `31000000
	dw `00000000
	dw `02000031
	
	dw `20000000
	dw `00000000
	dw `00132000
	dw `00133000
	dw `00032000
	dw `00332000
	dw `00231000
	dw `00000000
	
	dw `01120330
	dw `00223030
	dw `00112030
	dw `00111300
	dw `00011200
	dw `00011200
	dw `00011300
	dw `00011300
	; Fourth row
	dw `00300120
	dw `00300010
	dw `03010000
	dw `03031000
	dw `03303100
	dw `03330032
	dw `03333300
	dw `00000000
	
	dw `03031002
	dw `01303320
	dw `00000000
	dw `00011000
	dw `00000000
	dw `21000003
	dw `00333333
	dw `00000000
	
	dw `00002000
	dw `00021000
	dw `00210000
	dw `00000001
	dw `00001111
	dw `21111123
	dw `22131223
	dw `00000000
	
	dw `00011300
	dw `00111300
	dw `01111200
	dw `00003030
	dw `00030330
	dw `33203330
	dw `00033330
	dw `00000000
TilesEnd:


SECTION "Paddle", ROM0

Paddle:
	dw `13333331
	dw `30000003
	dw `13333331
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
PaddleEnd:


SECTION "Ball", ROM0

Ball:
	dw `00033000
	dw `00322300
	dw `03222230
	dw `03222230
	dw `00322300
	dw `00033000
	dw `00000000
	dw `00000000
BallEnd:


SECTION "Tile map", ROM0

Tilemap:
	db $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $0B, $0C, $0D, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0E, $0F, $10, $11, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $12, $13, $14, $15, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $16, $17, $18, $19, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
TilemapEnd:

; Variables
;SECTION "Counter" , WRAM0
;wFrameCounter: db


SECTION "Input variables", WRAM0
wCurKeys: db
wNewKeys: db


SECTION "Ball Data", WRAM0
wBallMomentumX: db
wBallMomentumY: db
