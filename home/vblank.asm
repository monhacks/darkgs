; VBlank is the interrupt responsible for updating VRAM.

; In Pokemon Crystal, VBlank has been hijacked to act as the
; main loop. After time-sensitive graphics operations have been
; performed, joypad input and sound functions are executed.

; This prevents the display and audio output from lagging.

VBlank::
	push af
	push bc
	push de
	push hl

	ldh a, [hROMBank]
	ldh [hROMBankBackup], a

	ldh a, [hVBlank]
	and 7
	add a

	ld e, a
	ld d, 0
	ld hl, .VBlanks
	add hl, de
	ld a, [hli]
	ld h, [hl]
	ld l, a

	call _hl_

	call GameTimer

	xor a
	ld [wVBlankOccurred], a

	ldh a, [hROMBankBackup]
	rst Bankswitch

	pop hl
	pop de
	pop bc
	pop af
	reti

.VBlanks:
	dw VBlank0
	dw VBlank1
	dw VBlank2
	dw VBlank3
	dw VBlank4
	dw VBlank5
	dw VBlank6
	dw VBlank7

VBlank0::
; normal operation

; rng
; scx, scy, wy, wx
; bg map buffer
; palettes
; dma transfer
; bg map
; tiles
; oam
; joypad
; sound

	ldh a, [hSCX]
	ldh [rSCX], a
	ldh a, [hSCY]
	ldh [rSCY], a
	ldh a, [hWY]
	ldh [rWY], a
	ldh a, [hWX]
	ldh [rWX], a

	; There's only time to call one of these in one vblank.
	; Calls are in order of priority.

	call UpdateBGMapBuffer
	jr c, .done
	call UpdatePalsIfCGB
	jr c, .done
	call DMATransfer
	jr c, .done
	call UpdateBGMap

	; These have their own timing checks.

	call Serve2bppRequest
	call Serve1bppRequest
	call AnimateTileset

.done

	ldh a, [hOAMUpdate]
	and a
	call z, hTransferShadowOAM
.done_oam

	; vblank-sensitive operations are done

	; inc frame counter
	ld hl, hVBlankCounter
	inc [hl]

	; advance random variables
	ldh a, [rDIV]
	ld b, a
	ldh a, [hRandomAdd]
	adc b
	ldh [hRandomAdd], a

	ldh a, [rDIV]
	ld b, a
	ldh a, [hRandomSub]
	sbc b
	ldh [hRandomSub], a

	xor a
	ld [wVBlankOccurred], a

	ld a, [wTextDelayFrames]
	and a
	jr z, .ok2
	dec a
	ld [wTextDelayFrames], a
.ok2

	call UpdateJoypad

	; fallthrough

VBlank2::
; sound only

	ld a, BANK(_UpdateSound)
	rst Bankswitch
	jmp _UpdateSound

VBlank1::
; scx, scy
; palettes
; bg map
; tiles
; oam
; sound / lcd stat

	ldh a, [hSCX]
	ldh [rSCX], a
	ldh a, [hSCY]
	ldh [rSCY], a

	call UpdatePals
	jr c, .done

	call UpdateBGMap
	call Serve2bppRequest_VBlank

	call hTransferShadowOAM

.done

	; get requested ints
	ldh a, [rIF]
	ld b, a
	; discard requested ints
	xor a
	ldh [rIF], a
	; enable lcd stat
	ld a, 1 << LCD_STAT
	ldh [rIE], a
	; rerequest serial int if applicable (still disabled)
	; request lcd stat
	ld a, b
	and 1 << SERIAL
	or 1 << LCD_STAT
	ldh [rIF], a

	ei
	call VBlank2
	di

	; get requested ints
	ldh a, [rIF]
	ld b, a
	; discard requested ints
	xor a
	ldh [rIF], a
	; enable ints besides joypad
	ld a, IE_DEFAULT
	ldh [rIE], a
	; rerequest ints
	ld a, b
	ldh [rIF], a
	ret

UpdatePals::
; update pals for either dmg or cgb

	ldh a, [hCGB]
	and a
	jmp nz, UpdateCGBPals

	; update gb pals
	ld a, [wBGP]
	ldh [rBGP], a
	ld a, [wOBP0]
	ldh [rOBP0], a
	ld a, [wOBP1]
	ldh [rOBP1], a

	and a
	ret

VBlank3::
; scx, scy
; palettes
; bg map
; tiles
; oam
; sound / lcd stat

	ldh a, [hSCX]
	ldh [rSCX], a
	ldh a, [hSCY]
	ldh [rSCY], a

	ldh a, [hCGBPalUpdate]
	and a
	call nz, ForceUpdateCGBPals
	jr c, .done

	call UpdateBGMap
	call Serve2bppRequest_VBlank

	call hTransferShadowOAM
.done

	ldh a, [rIF]
	push af
	xor a
	ldh [rIF], a
	ld a, 1 << LCD_STAT
	ldh [rIE], a
	ldh [rIF], a

	ei
	call VBlank2
	di

	; request lcdstat
	ldh a, [rIF]
	ld b, a
	; and any other ints
	pop af
	or b
	ld b, a
	; reset ints
	xor a
	ldh [rIF], a
	; enable ints besides joypad
	ld a, IE_DEFAULT
	ldh [rIE], a
	; request ints
	ld a, b
	ldh [rIF], a
	ret

VBlank4::
; bg map
; tiles
; oam
; joypad
; serial
; sound

	call UpdateBGMap
	call Serve2bppRequest

	call hTransferShadowOAM

	call UpdateJoypad

	jmp VBlank2

VBlank5::
; scx
; palettes
; bg map
; tiles
; joypad
;

	ldh a, [hSCX]
	ldh [rSCX], a

	call UpdatePalsIfCGB
	jr c, .done

	call UpdateBGMap
	call Serve2bppRequest
.done

	call UpdateJoypad

	xor a
	ldh [rIF], a
	ld a, 1 << LCD_STAT
	ldh [rIE], a
	; request lcd stat
	ldh [rIF], a

	ei
	call VBlank2
	di

	xor a
	ldh [rIF], a
	; enable ints besides joypad
	ld a, IE_DEFAULT
	ldh [rIE], a
	ret

VBlank6::
; palettes
; tiles
; dma transfer
; sound

	; inc frame counter
	ld hl, hVBlankCounter
	inc [hl]

	call UpdateCGBPals
	jr c, .done

	call Serve2bppRequest
	call Serve1bppRequest
	call DMATransfer
.done

	jmp VBlank2

VBlank7:
	; special vblank routine
	; copies tilemap in one frame without any tearing
	; also updates oam, and pals if specified
	push af
	homecall VBlankSafeCopyTilemapAtOnce
	xor a
	ld [wVBlankOccurred], a
	pop af
	ret
