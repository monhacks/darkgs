GetEmote2bpp:
	ld a, $1
	ldh [rVBK], a
	call Get2bpp
	xor a
	ldh [rVBK], a
	ret

_UpdatePlayerSprite::
	call GetPlayerSprite
	ld a, [wUsedSprites]
	ldh [hUsedSpriteIndex], a
	ld a, [wUsedSprites + 1]
	ldh [hUsedSpriteTile], a
	jmp GetUsedSprite

_RefreshSprites: ; mobile
	ld hl, wSpriteFlags
	ld a, [hl]
	push af
	res 7, [hl]
	set 6, [hl]
	call LoadUsedSpritesGFX
	pop af
	ld [wSpriteFlags], a
	ret

_ClearSprites: ; mobile
	ld hl, wSpriteFlags
	ld a, [hl]
	push af
	set 7, [hl]
	res 6, [hl]
	call LoadUsedSpritesGFX
	pop af
	ld [wSpriteFlags], a
	ret

GetPlayerSprite:
; Get Chris or Kris's sprite.
	ld hl, ChrisStateSprites
	ld a, [wPlayerSpriteSetupFlags]
	bit PLAYERSPRITESETUP_FEMALE_TO_MALE_F, a
	jr nz, .go
	ld a, [wPlayerGender]
	bit PLAYERGENDER_FEMALE_F, a
	jr z, .go
	ld hl, KrisStateSprites

.go
	ld a, [wPlayerState]
	ld c, a
.loop
	ld a, [hli]
	cp c
	jr z, .good
	inc hl
	cp -1
	jr nz, .loop

; Any player state not in the array defaults to Chris's sprite.
	xor a ; ld a, PLAYER_NORMAL
	ld [wPlayerState], a
	ld a, SPRITE_CHRIS
	jr .finish

.good
	ld a, [hl]

.finish
	ld [wUsedSprites + 0], a
	ld [wPlayerSprite], a
	ld [wPlayerObjectSprite], a
	ret

INCLUDE "data/sprites/player_sprites.asm"

RefreshSprites::
	push hl
	push de
	push bc
	call GetPlayerSprite
	xor a
	ld [hUsedSpriteIndex], a
	call ReloadSpriteIndex
	call LoadMiscTiles
	pop bc
	pop de
	pop hl
	ret

ReloadSpriteIndex::
; Reloads sprites using hUsedSpriteIndex.
; Used to reload variable sprites
	ld hl, wObjectStructs
	ld de, OBJECT_LENGTH
	push bc
	ld a, [hUsedSpriteIndex]
	ld b, a
	xor a
.loop
	ld [hObjectStructIndex], a
	ld a, [hl]
	and a
	jr z, .done
	bit 7, b
	jr z, .continue
	cp b
	jr nz, .done
.continue
	push hl
	call GetSpriteVTile
	pop hl
	push hl
	inc hl
	inc hl
	ld [hl], a
	pop hl
.done
	add hl, de
	ld a, [hObjectStructIndex]
	inc a
	cp NUM_OBJECT_STRUCTS
	jr nz, .loop
	pop bc
	ret

LoadUsedSpritesGFX:
	ld a, MAPCALLBACK_SPRITES
	call RunMapCallback
	call GetUsedSprites
	jr LoadMiscTiles

LoadMiscTiles:
	ld a, [wSpriteFlags]
	bit 6, a
	ret nz

	ld c, EMOTE_POKE_BALL
	farcall LoadEmote

	ld c, EMOTE_SHADOW
	farcall LoadEmote
	call GetMapEnvironment
	call CheckOutdoorMap
	ld c, EMOTE_GRASS_RUSTLE
	jr z, .outdoor
	ld c, EMOTE_BOULDER_DUST
.outdoor
	farcall LoadEmote
	ret

SafeGetSprite:
	push hl
	call GetSprite
	pop hl
	ret

GetSprite::
	call GetFollowingSprite
	ret c
	call GetMonSprite
	ret c

	ld hl, OverworldSprites + SPRITEDATA_ADDR
	dec a
	ld c, a
	ld b, 0
	ld a, NUM_SPRITEDATA_FIELDS
	call AddNTimes
	; load the address into de
	ld a, [hli]
	ld e, a
	ld a, [hli]
	ld d, a
	; load the length into c
	ld a, [hli]
	swap a
	ld c, a
	; load the sprite bank into both b and h
	ld b, [hl]
	ld a, [hli]
	; load the sprite type into l
	ld l, [hl]
	ld h, a
	ret

GetMonSprite:
; Return carry if a monster sprite was loaded.

	cp SPRITE_POKEMON
	jr c, .Normal
	cp SPRITE_DAY_CARE_MON_1
	jr z, .BreedMon1
	cp SPRITE_DAY_CARE_MON_2
	jr z, .BreedMon2
	cp SPRITE_VARS
	jr nc, .Variable
	jr .pokemon_sprite

.Normal:
	and a
	ret

.pokemon_sprite:
	sub SPRITE_POKEMON
	ld e, a
	ld d, 0
	ld hl, SpriteMons
	add hl, de
	add hl, de
	ld a, [hli]
	ld h, [hl]
	ld l, a
	call GetPokemonIDFromIndex
	jr GetWalkingMonSprite

.BreedMon1
	ld a, [wBreedMon1Species]
	jr GetWalkingMonSprite

.BreedMon2
	ld a, [wBreedMon2Species]
	jr GetWalkingMonSprite

.Variable:
	sub SPRITE_VARS
	ld e, a
	ld d, 0
	ld hl, wVariableSprites
	add hl, de
	ld a, [hl]
	and a
	jr nz, GetMonSprite

GetFirstAliveMon::
; Returns [wParty#Sprite] in a; party number in d
	ld a, [wPartyCount]
	and a
	ret z
	inc a
	ld d, 1
	ld e, a
	ld bc, wPartyMon1
.loop
	ld hl, MON_HP
	add hl, bc
	ld a, [hli]
	push de
	ld d, a
	ld a, [hl]
	or d
	pop de
	jr nz, .got_mon_struct
	inc d
	ld a, d
	cp e
	ret z
	ld hl, PARTYMON_STRUCT_LENGTH
	add hl, bc
	ld b, h
	ld c, l
	jr .loop
.got_mon_struct
	ld a, [bc]
	ret

GetStoragePCSprite:
	ld a, b
	jr GetWalkingMonSprite

GetFollowingSprite:
	cp SPRITE_FOLLOWER
	jr nz, GetWalkingMonSprite.nope

	call GetFirstAliveMon
	ld [wFollowerSpriteID], a
	push af
	ld a, d
	ld [wFollowerPartyNum], a
	pop af

GetWalkingMonSprite:
	push af
	call GetPokemonIndexFromID
	ld a, h
	and a
	jr nz, .good_id
	ld a, l
	and a
	jr z, .nope_pop_af ; BAD ID!
.good_id
	dec hl
	ld b, h
	ld c, l

	ld hl, FollowingSpritePointers

	ld a, b
	cp HIGH(UNOWN - 1) ; we already decremented
	jr nz, .not_unown
	ld a, c
	cp LOW(UNOWN - 1) ; we already decremented
	jr nz, .not_unown
	ld a, [wFollowerPartyNum]
	dec a
	ld bc, PARTYMON_STRUCT_LENGTH
	ld hl, wPartyMon1Form
	call AddNTimes
	predef GetUnownLetter
	ld a, [wUnownLetter]
	dec a
	ld hl, UnownFollowingSpritePointers
	ld b, 0
	ld c, a

.not_unown
	add hl, bc
	add hl, bc
	add hl, bc
	assert BANK(FollowingSpritePointers) == BANK(UnownFollowingSpritePointers), \
			"FollowingSpritePointers Bank is not equal to UnownFollowingSpritePointers"
	ld a, BANK(FollowingSpritePointers)
	push af
	call GetFarByte
	ld b, a
	inc hl
	pop af
	call GetFarWord

	ldh a, [rSVBK]
	push af
	ld a, BANK(wDecompressScratch)
	ldh [rSVBK], a

	push bc
	ld a, b
	ld de, wDecompressScratch
	call FarDecompress
	pop bc
	ld de, wDecompressScratch

	pop af
	ldh [rSVBK], a

	ld h, 0
	ld c, 12
	ld l, WALKING_SPRITE

	pop af

	scf
	ret
.nope_pop_af
	pop af
.nope
	and a
	ret

_DoesSpriteHaveFacings::
; Checks to see whether we can apply a facing to a sprite.
; Returns carry unless the sprite is a Pokemon or a Still Sprite.
	cp SPRITE_FOLLOWER
	jr z, .follower
	cp SPRITE_POKEMON
	jr nc, .only_down

	push hl
	push bc
	ld hl, OverworldSprites + SPRITEDATA_TYPE
	dec a
	ld c, a
	ld b, 0
	ld a, NUM_SPRITEDATA_FIELDS
	call AddNTimes
	ld a, [hl]
	pop bc
	pop hl
	cp STILL_SPRITE
	jr nz, .only_down
	scf
	ret

.follower
	ld a, WALKING_SPRITE

.only_down
	and a
	ret

_GetSpritePalette::
	ld a, c
	push bc
	call GetFollowingSprite
	pop bc
	jr c, .follower
	ld a, c
	push bc
	call GetMonSprite
	pop bc
	jr c, .is_pokemon

	ld hl, OverworldSprites + SPRITEDATA_PALETTE
	dec a
	ld c, a
	ld b, 0
	ld a, NUM_SPRITEDATA_FIELDS
	call AddNTimes
	ld c, [hl]
	ret

.is_pokemon
	call GetPokemonIndexFromID
	ld a, h
	and a
	jr nz, .good_id_1
	ld a, l
	and a
	ret z ; Bad ID!
.good_id_1
	dec hl
	push de
	ld de, MenuMonPals
	add hl, de
	ld a, BANK(MenuMonPals)
	call GetFarByte
	ld d, a
	ld a, c
	cp SPRITE_DAY_CARE_MON_1
	ld bc, wBreedMon1Shiny
	jr z, .check_shiny
	cp SPRITE_DAY_CARE_MON_2
	ld bc, wBreedMon2Shiny
	jr z, .check_shiny
	ld a, d
	pop de
	jr .not_shiny

.follower
	call GetPokemonIndexFromID
	ld a, h
	and a
	jr nz, .good_id
	ld a, l
	and a
	ret z ; Bad ID!
.good_id
	dec hl
	ld b, h
	ld c, l
	ld hl, MenuMonPals
	add hl, bc
	ld a, BANK(MenuMonPals)
	call GetFarByte
	push de
	ld d, a
	ld a, [wFollowerPartyNum]
	dec a
	ld hl, wPartyMon1Shiny
	call GetPartyLocation
	ld b, h
	ld c, l
.check_shiny
	farcall CheckShininess
	ld a, d
	pop de
	jr c, .shiny
.not_shiny
	swap a
.shiny
	and $f
	ld hl, FollowingPalLookupTable
	ld b, 0
	ld c, a
	add hl, bc
	ld a, BANK(FollowingPalLookupTable)
	call GetFarByte
	ld c, a
	ret

AddSpriteGFX:
; Add any new sprite ids to a list of graphics to be loaded.
; Return carry if the list is full.

	push hl
	push bc
	ld b, a
	ld hl, wUsedSprites + 2
	ld c, SPRITE_GFX_LIST_CAPACITY - 1
.loop
	ld a, [hl]
	cp b
	jr z, .exists
	and a
	jr z, .new
	inc hl
	inc hl
	dec c
	jr nz, .loop

	pop bc
	pop hl
	scf
	ret

.exists
	pop bc
	pop hl
	and a
	ret

.new
	ld [hl], b
	pop bc
	pop hl
	and a
	ret

GetSpriteLength:
; Return the length of sprite type a in tiles.

	cp WALKING_SPRITE
	jr z, .AnyDirection
	cp STANDING_SPRITE
	jr z, .AnyDirection
	cp STILL_SPRITE
	jr z, .OneDirection

	ld a, 12
	ret

.AnyDirection:
	ld a, 12
	ret

.OneDirection:
	ld a, 4
	ret

GetUsedSprites:
	ld hl, wUsedSprites
	ld c, SPRITE_GFX_LIST_CAPACITY

.loop
	ld a, [wSpriteFlags]
	res 5, a
	ld [wSpriteFlags], a

	ld a, [hli]
	and a
	jr z, .done
	ldh [hUsedSpriteIndex], a

	ld a, [hli]
	ldh [hUsedSpriteTile], a

	bit 7, a
	jr z, .dont_set

	ld a, [wSpriteFlags]
	set 5, a ; load VBank0
	ld [wSpriteFlags], a

.dont_set
	push bc
	push hl
	call GetUsedSprite
	pop hl
	pop bc
	dec c
	jr nz, .loop

.done
	ret

GetUsedSprite::
	ldh a, [hUsedSpriteIndex]
	call SafeGetSprite
	ldh a, [hUsedSpriteTile]
	call .GetTileAddr
	push hl
	push de
	push bc
	ld a, [wSpriteFlags]
	bit 7, a
	jr nz, .skip
	call .CopyToVram

.skip
	pop bc
	ld l, c
	ld h, $0
rept 4
	add hl, hl
endr
	pop de
	add hl, de
	ld d, h
	ld e, l
	pop hl

	ld a, [wSpriteFlags]
	bit 5, a
	jr nz, .done
	bit 6, a
	jr nz, .done

	ldh a, [hUsedSpriteIndex]
	call _DoesSpriteHaveFacings
	jr c, .done

	ld a, h
	add HIGH(vTiles1 - vTiles0)
	ld h, a
	call .CopyToVram

.done
	ret

.GetTileAddr:
; Return the address of tile (a) in (hl).
	and $7f
	ld l, a
	ld h, 0
rept 4
	add hl, hl
endr
	ld a, l
	add LOW(vTiles0)
	ld l, a
	ld a, h
	adc HIGH(vTiles0)
	ld h, a
	ret

.CopyToVram:
	ldh a, [rVBK]
	push af
	ld a, [wSpriteFlags]
	bit 5, a
	ld a, $1
	jr z, .bankswitch
	ld a, $0

.bankswitch
	ldh [rVBK], a

	ldh a, [rSVBK]
	push af
	ld a, BANK(wDecompressScratch)
	ldh [rSVBK], a

	call Get2bpp

	pop af
	ldh [rSVBK], a

	pop af
	ldh [rVBK], a
	;farcall CopySpritePal
	ret

LoadEmote::
; Get the address of the pointer to emote c.
	ld a, c
	ld bc, EMOTE_LENGTH
	ld hl, Emotes
	call AddNTimes
; Load the emote address into de
	ld e, [hl]
	inc hl
	ld d, [hl]
; load the length of the emote (in tiles) into c
	inc hl
	ld c, [hl]
	swap c
; load the emote pointer bank into b
	inc hl
	ld b, [hl]
; load the VRAM destination into hl
	inc hl
	ld a, [hli]
	ld h, [hl]
	ld l, a
; if the emote has a length of 0, do not proceed (error handling)
	ld a, c
	and a
	ret z
	jmp GetEmote2bpp

INCLUDE "data/sprites/emotes.asm"

INCLUDE "data/sprites/sprite_mons.asm"

INCLUDE "data/sprites/sprites.asm"
