; tell the compiler that this code will be loaded at memory address $8000 in the NES
.org $8000

; see https://wiki.nesdev.com/w/index.php/PPU_registers
PPUCTRL               = $2000
PPUMASK               = $2001
PPUSTATUS             = $2002
PPUSCROLL             = $2005
PPUADDR               = $2006
PPUDATA               = $2007
OAMDMA                = $4014
JOYPAD_PORT           = $4016

; some ram addresses used by our program
Procedure     = $7FF
ProcedureAddr = $7FD
Sequence = $F
Victories = $77F
HeldButtons = $C0

; this code will run at startup, or when reset is pressed.
BOOT:
    ; enable interrupts
    sei
    cld
    ; clear the stack
    ldx #$FF
    txs
    bit PPUSTATUS
    ; delay for two frames, to make sure the ppu has started
:   bit PPUSTATUS
    bpl :-
:   bit PPUSTATUS
    bpl :-
    ; set some initial ram state
    lda #0
    sta Procedure
    ; enable background layer
    lda #%00001000
    sta PPUMASK
    ; enable NMI interrupt
    lda #%10000000
    sta PPUCTRL
    ; loop until NMI
:   jmp :-

; this interrupt executes every frame
NMI:
    ; clear stack
    ldx #$FF
    txs
    ; run a procedure from the nmiprocedures list
    jsr NMIProcedure
    ; loop until next NMI
:   jmp :-

NMIProcedure:
    ; get the next procedure to run, and multiply by 2
    lda Procedure
    asl a
    tax
    ; copy the address to the procedure to run
    lda NMIProcedures, x
    sta ProcedureAddr
    lda NMIProcedures+1, x
    sta ProcedureAddr+1
    ; and execute that function
    jmp (ProcedureAddr)

; nmi procedures has a list of different things that can run at the start of the frame
NMIProcedures:
    ; setup initializes graphics
    .addr Setup
    ; do nothing does nothing
    .addr DoNothing

; this is a macro to write data to the ppu
.macro WriteDataToPPU PPU, Start, Len
    ; update the ppu location
    lda #>PPU
    sta PPUADDR
    lda #<PPU
    sta PPUADDR
    ; and write 'Len' bytes to ppu, starting at the memory location in 'Start'
    ldx #0
:
    lda Start,x
    sta PPUDATA
    inx
    cpx #Len
    bne :-
.endmacro

; setup initializes some ppu data
Setup:
    ; first disable the NMI interrupt so that we can copy data to the ppu without
    ; worrying about getting interrupted
    lda #%00000000
    sta PPUCTRL
    ; then we set the Procedure to run next frame
    lda #1
    sta Procedure
    ; copy palette data to the PPU
    WriteDataToPPU $3F00, MenuPalette, MenuPaletteEnd - MenuPalette
    ; copy hello world text to the PPU
    WriteDataToPPU $2041, TextHello, TextHelloEnd - TextHello
    WriteDataToPPU $2141, TextVictories, TextVictoriesEnd - TextVictories
    ; and reset the PPU scroll position to the top left corner
    lda #0
    sta Victories
    sta Sequence
    sta PPUSCROLL
    sta PPUSCROLL
    ; then re-enable NMI so the next frame can run
    lda #%10000000
    sta PPUCTRL
    rts



; do nothing!
DoNothing:
    ldy Sequence
    jsr ShowSequenceValue
    jsr ReadJoypadsCurrent
    ldy Sequence

    ; dont press any of the bad inputs!
    lda ExpectedNotInputs,y
    and HeldButtons
    bne @fail

    ; dont not press any of the good inputs!
    lda ExpectedInputs,y
    sta $11
    and HeldButtons
    cmp $11
    bne @fail

    ; looking good!
    inc Sequence
    ldy Sequence
    lda ExpectedInputs,y
    cmp #$FF
    beq @winner
    rts
@winner:
    inc Victories
@fail:
    lda #0
    sta Sequence

    ; this does nothing!
    rts

ShowSequenceValue:
    tya
    asl a
    tay
    lda SeqMessages,y
    sta $10
    lda SeqMessages+1,y
    sta $11
    lda #$20
    sta PPUADDR
    lda #$C1
    sta PPUADDR
    ldy #0
    lda ($10),y
    sta PPUDATA
    iny
    lda ($10),y
    sta PPUDATA
    iny
    lda ($10),y
    sta PPUDATA
    iny
    lda ($10),y
    sta PPUDATA
    iny
    lda ($10),y
    sta PPUDATA
    iny
    lda ($10),y
    sta PPUDATA
    iny
    lda ($10),y
    sta PPUDATA
    iny
    lda ($10),y
    sta PPUDATA
    iny
    lda ($10),y
    sta PPUDATA
    lda #$21
    sta PPUADDR
    lda #$41
    sta PPUADDR
    lda Victories
    adc #$10
    sta PPUDATA
    lda #0
    sta PPUSCROLL
    sta PPUSCROLL
    rts

BTN_A = %10000000
BTN_B = %01000000
BTN_S = %00100000
BTN_T = %00010000
BTN_U = %00001000
BTN_D = %00000100
BTN_L = %00000010
BTN_R = %00000001

ExpectedInputs:
.byte BTN_L
.byte BTN_R
.byte BTN_L | BTN_A
.byte BTN_R
.byte $FF

ExpectedNotInputs:
.byte BTN_R | BTN_A
.byte BTN_L | BTN_A
.byte BTN_R | BTN_D
.byte BTN_L
.byte $FF

SeqMessages:
.addr Message0
.addr Message1
.addr Message2
.addr Message1

Message0: .byte "PRESS L  "
Message1: .byte "PRESS R  "
Message2: .byte "PRESS LA "


ReadJoypadsCurrent:
    lda #$01
    sta JOYPAD_PORT
    sta HeldButtons
    lsr a
    sta JOYPAD_PORT
@KeepReading:
    lda JOYPAD_PORT
    lsr a
    rol HeldButtons
    bcc @KeepReading
    rts


; the palette consists of up to 8 groups of 4 colors each
; the first color is the screen background
MenuPalette:
.byte $0F, $30, $10, $00
.byte $0F, $30, $10, $00
.byte $0F, $30, $10, $00
.byte $0F, $30, $10, $00
MenuPaletteEnd:

TextHello:
.byte "PRESS L R L-A R TO WIN"
TextHelloEnd:

TextVictories:
.byte "0 VICTORIES"
TextVictoriesEnd:

; next we want to skip ahead to the very end of the ROM
; and write our interrupts so that the NES knows where in PRG to jump
; on each frame and when the reset button is pressed.
.res $FFFA - *, $00
.word NMI
.word BOOT
.word $fff0