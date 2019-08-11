/*
	Simple audio routine for the SEGA SC-3000.
	Developed in 2019 for use in the Staffhaven RPG game by Andrew Kerr, with assistance
	  from Nick Hook. Both are co-founders of SEGA Survivors (www.sc-3000.com).
	
	Usage:
	Convenient for use with MIDI files containing no more than 3 tonal channels and 1
	"percussion" (white noise) channel.  MIDI frequencies can be converted using the
	following:
	MIDI KEY  SN76489AN Freq
	    45          110
	    46          117
	    ..          ...
	    ..          ...
	   104         3322
	   105         3520
	
	  Use the formula INT( 3840000 / ( SN76489AN_Freq * 32 ) ) to derive the tonal byte
	  For further details, please refer to the SN76489AN sound chip spec, available online
	    and refer to the midi2sc3000.ods for a working conversion sheet.

	Details:
	* A ticker starts at zero and increments by 1 each loop. Within each loop, each channel
	  is checked for an Event, the event is actioned and the
	  corresponding channel data pointer is incremented to the next potential event. If the
	  event time equals the end-of-audio
	* Audio data is split by channels, with the structure made up of :
		- Event Time (2 bytes)
		- Tone (2 bytes, refer to sound chip specs)
		- Volume (1 byte)
	* Channel is terminated with $0000 (actually, any value less than the previous event's
	  time for that channel, but using $0000 is simpler), except for the longest-running
	  channel (see next point).
	* Use $FFFF to terminate the longest-running channel, i.e. the channel with the largest
	  Event Time value. If there are multiple channels with the largest Event Time, place the
	  $FFFF in the lowest-value channel, i.e. if channel 1 is short and channel 2 + 3 have
	  events that occur after channel 1 has ended, use $0000 to terminate channels 1 and 3 and
	  use $FFFF to terminate channel 2.

	  Additional:
	  * Adjust DELAY_VAL to control tempo.
	  * To support audio events beyond $FFFF, either adjust the code to use a multi-word ticker or
	    simply find a value that all event times are evenly divisable by and scale the event times
		by that value, you will also need to adjust the DELAY_VAL accordingly.
*/
.target "z80"
.setting "OutputFileType", "bin"
.setting "OutputSaveEntireBanks", true
.bank 0, 64, $0000

//Constants
	TICKER_POS   = $C000
	CH1DATA_POS  = $C002
	CH2DATA_POS  = $C004
	DELAY_POS    = $C006
	DELAY_VAL    = $0100
	STACKPOINTER = $C010
	EOA_FLAG     = $FFFF
    SOUNDPORT  = $7F
    Ch1VolOff  = $9F
    Ch1VolFull = $90
    Ch2VolOff  = $BF
    Ch2VolFull = $B0
    Ch3VolOff  = $DF
    Ch3VolFull = $D0
    Ch4VolOff  = $FF
    Ch4VolFull = $F0

.org $0000
RESET
	di
	im 1
	jp PLAY_AUDIO

.org $0066
PAUSE_NMI
	retn

.org $0100
PLAY_AUDIO
	ld hl,DELAY_VAL
	ld(DELAY_POS),hl
	ld sp,STACKPOINTER
	call SILENCE_CHANNELS
	ld hl,CH1_AUDIO
	ld(CH1DATA_POS),hl
	ld hl,CH2_AUDIO
	ld(CH2DATA_POS),hl
	ld hl,$0000
	ld(TICKER_POS),hl

AUDIO_LOOP
	//Check for channel 1 output.
	push hl
	ld hl,(CH1DATA_POS)
	ld e,(hl)
	inc hl
	ld d,(hl)
	pop hl
	or a
	sbc hl,de
	add hl,de
	jp z,OUPUT_CH1 //Jump if ticker = audio event time.
	//else
	//Check for audio end.
	push hl 
	ld hl,EOA_FLAG
	or a
	sbc hl,de
	add hl,de
	jp z,FINISH //Jump if ticker = end-of-audio flag.
	pop hl

CH2_CHECK
	//Check for channel 2 output.
	push hl
	ld hl,(CH2DATA_POS)
	ld e,(hl)
	inc hl
	ld d,(hl)
	pop hl
	or a
	sbc hl,de
	add hl,de
	jp z,OUPUT_CH2 //Jump if ticker = audio event time.

AUDIO_LOOP_END
	call DELAY
	inc hl
	ld(TICKER_POS),hl
	jp AUDIO_LOOP

FINISH
	call SILENCE_CHANNELS
    ei
    jp *

OUPUT_CH1
	push hl //Ticker
	ld hl,(CH1DATA_POS)
	inc hl
	inc hl
	ld b,3
	ld c,SOUNDPORT
	otir
	ld(CH1DATA_POS),hl
	pop hl //Ticker
	jp CH2_CHECK

OUPUT_CH2
	push hl //Ticker
	ld hl,(CH2DATA_POS)
	inc hl
	inc hl
	ld b,3
	ld c,SOUNDPORT
	otir
	ld(CH2DATA_POS),hl
	pop hl //Ticker
	jp AUDIO_LOOP_END

DELAY
    ld bc,(DELAY_POS)
@INNER_LOOP
	dec c
	jp nz,@INNER_LOOP
	dec b
	jp nz,@INNER_LOOP
    ret

SILENCE_CHANNELS
    ld a,Ch1VolOff
    out (SOUNDPORT),a
    ld a,Ch2VolOff
    out (SOUNDPORT),a
    ld a,Ch3VolOff
    out (SOUNDPORT),a
    ld a,Ch4VolOff
    out (SOUNDPORT),a
    ret
//Event Ticker (2 bytes), Tone (1st byte), Tone (2nd byte), Volume
CH1_AUDIO
	.byte $00,$00,$81,$1B,$90
	.byte $74,$00,$81,$1B,$9F
	.byte $78,$00,$81,$18,$90
	.byte $EC,$00,$81,$18,$9F
	.byte $F0,$00,$8B,$16,$90
	.byte $64,$01,$8B,$16,$9F
	.byte $68,$01,$81,$18,$90
	.byte $DC,$01,$81,$18,$9F
	.byte $E0,$01,$85,$1E,$90
	.byte $CC,$02,$85,$1E,$9F
	.byte $D0,$02,$8B,$16,$90
	.byte $BC,$03,$8B,$16,$9F
	.byte $C0,$03,$85,$1E,$90
	.byte $AC,$04,$85,$1E,$9F
	.byte $B0,$04,$81,$18,$90
	.byte $9C,$05,$81,$18,$9F
	.byte $A0,$05,$81,$1B,$90
	.byte $8C,$06,$81,$1B,$9F
	.byte $90,$06,$81,$18,$90
	.byte $DC,$06,$81,$18,$9F
	.byte $E0,$06,$8B,$16,$90
	.byte $2C,$07,$8B,$16,$9F
	.byte $30,$07,$81,$18,$90
	.byte $7C,$07,$81,$18,$9F
	.byte $80,$07,$81,$1B,$90
	.byte $6C,$08,$81,$1B,$9F
	.byte $70,$08,$87,$2D,$90
	.byte $5C,$09,$87,$2D,$9F
	.byte $60,$09,$81,$1B,$90
	.byte $4C,$0A,$81,$1B,$9F
	.byte $50,$0A,$81,$30,$90
	.byte $3C,$0B,$81,$30,$9F
	.byte $40,$0B,$81,$1B,$90
	.byte $2C,$0C,$81,$1B,$9F
	.byte $30,$0C,$81,$18,$90
	.byte $7C,$0C,$81,$18,$9F
	.byte $80,$0C,$8B,$16,$90
	.byte $CC,$0C,$8B,$16,$9F
	.byte $D0,$0C,$81,$18,$90
	.byte $1C,$0D,$81,$18,$9F
	.byte $20,$0D,$81,$1B,$90
	.byte $0C,$0E,$81,$1B,$9F
	.byte $10,$0E,$8B,$16,$90
	.byte $FC,$0E,$8B,$16,$9F
	.byte $00,$0F,$81,$18,$90
	.byte $EC,$0F,$81,$18,$9F
	.byte $F0,$0F,$85,$1E,$95
	.byte $DC,$10,$85,$1E,$9F
	.byte $E0,$10,$81,$1B,$90
	.byte $CC,$11,$81,$1B,$9F
	.byte $D0,$11,$81,$18,$90
	.byte $BC,$12,$81,$18,$9F
	.byte $C0,$12,$8B,$16,$90
	.byte $34,$13,$8B,$16,$9F
	.byte $38,$13,$81,$18,$90
	.byte $AC,$13,$81,$18,$9F
	.byte $B0,$13,$81,$1B,$90
	.byte $40,$15,$81,$1B,$9F
	.byte $FF,$FF

CH2_AUDIO
	.byte $00,$00,$AF,$35,$B0
	.byte $EC,$00,$AF,$35,$BF
	.byte $F0,$00,$A1,$1B,$B0
	.byte $DC,$01,$A1,$1B,$BF
	.byte $D0,$02,$A2,$22,$B0
	.byte $BC,$03,$A2,$22,$BF
	.byte $C0,$03,$AF,$3C,$B0
	.byte $34,$04,$AF,$3C,$BF
	.byte $B0,$04,$AF,$3C,$B0
	.byte $28,$05,$AF,$3C,$BF
	.byte $A0,$05,$AF,$35,$B0
	.byte $8C,$06,$AF,$35,$BF
	.byte $90,$06,$A0,$24,$B0
	.byte $7C,$07,$A0,$24,$BF
	.byte $80,$07,$AF,$35,$B0
	.byte $6C,$08,$AF,$35,$BF
	.byte $70,$08,$A2,$22,$B0
	.byte $60,$09,$A2,$22,$BF
	.byte $40,$0B,$AF,$35,$B0
	.byte $2C,$0C,$AF,$35,$BF
	.byte $30,$0C,$A0,$24,$B0
	.byte $1C,$0D,$A0,$24,$BF
	.byte $20,$0D,$AF,$35,$B0
	.byte $0C,$0E,$AF,$35,$BF
	.byte $10,$0E,$A2,$22,$B0
	.byte $FC,$0E,$A2,$22,$BF
	.byte $00,$0F,$AF,$35,$B0
	.byte $EC,$0F,$AF,$35,$BF
	.byte $F0,$0F,$A7,$2D,$B0
	.byte $DC,$10,$A7,$2D,$BF
	.byte $E0,$10,$AF,$35,$B0
	.byte $38,$13,$AF,$35,$BF
	.byte $B0,$13,$AF,$35,$B0
	.byte $40,$15,$AF,$35,$BF
	.byte $00,$00
.end