
Bitmap= $4000
CharRam= $6000
ColorRam= $D800


; 10 SYS2064

*=$0801

        BYTE    $0B, $08, $0A, $00, $9E, $32, $30, $36, $34, $00, $00, $00


*=$0810
        sei

        lda #%10111011          ;Switch to Multicolor Bitmap Mode, default : %10011011
        sta $d011               ;
                                ;
        lda #%00011000          ;default:00001000
        sta $d016               ;

        lda $dd00               ;Change vic memory access to Bank2: $4000-$7FFF
        and #%11111100
        ora #%00000010          
        sta $dd00

        lda #%10000000          ;Make Screen Ram(for colors 1 and 2) at vic address + $2000
        sta $d018

        lda #%01111111          ;switch off interrupt signals from CIA-1
        sta $DC0D

        lda $0001               ;Switch to memory map with only I/O and ram
        and #%11111000          
        ora #%00000101
        sta $0001

        lda #$00
        sta $d021
        lda #$12
        jsr CharRamInit
        lda #$55
        jsr ColorRamInit
        ;lda #%00011011
        lda #%00000000
        jsr BitmapInit

loop
;        inc @Test
;        lda @Test
        lda #%10101010
        jsr Draw2DPoly
;        inc MP1x
;        inc MP1x
;        dec MP2y
;        dec MP2y
;        dec MP2y
        lda #$00
        jsr BitmapInit
        jmp loop
        
@Test
        byte $00
        

        
        




Draw2DPoly              ;zeropage reserved:     $02 to $04 for ranking
                        ;                       $10 to $1B for sorted point data    
        sta @P
        ;jmp @DrawLine ;for testing
;ranking entry one: P1y's rank in lowness, so $00 stored in $02 would be P1y=lowest numberlowest number
        ldx #$00        ;x is ranking of P1
        ldy #$01        ;y is used as P2's rank, don't ask why it's 1 at first, too lazy to explain
        lda #$02        ;we use $04 directly, since we're already out of registers, that's why we love the 6502
        sta $04         

        lda MP1y+1
        cmp MP2y+1
        bne @skip1
        lda MP1y
        cmp MP2y
@skip1                  ;skip comparing small numbers if the biggies are different
        bcc @skip2
        inx
        dey             ;decrease P2's rank if P2y is lower than P1y
@skip2

        
        lda MP1y+1      ;now compare P1y with P3y, again, if they're equal, we pretend P1y is bigger
        cmp MP3y+1
        bne @skip3
        lda MP1y
        cmp MP3y
@skip3
        bcc @skip4
        inx
        dec $04         ;decrease P3's rank if P3y is lower than P1y
@skip4

        stx $02         ;store P1's rank

;now just compare P2y and P3y
        
        lda MP2y+1      ;now compare P2y with P3y, again, if they're equal, we pretend P2y is bigger
        cmp MP3y+1
        bne @skip5
        lda MP2y
        cmp MP3y
@skip5
        bcc @skip6
        iny
        dec $04         ;decrease P3's rank if P3y is lower than P2y
@skip6
        
        sty $03         ;store P2's rank, P3's rank doesn't need storing, since we subracted from $04 directly
        
     


;Now move it all to zpg (actually works)

        ;$05 used for
        ;$06 used for

        lda #<MP1x-1
        sta @SM1+1

        ldy #0  ;for index into rankdata
        ldx #4  ;4 bytes per point to be moved

@ArrangeOuterLoop

        lda $02,y       ;$02 for rank data
        asl     
        asl
        clc
        adc #@P1x-1
        sta @SM2+1

@ArrangeInnerLoop
@SM1
        lda MP1x-1,x    ;do the actual moving
@SM2
        sta @P1x-1,x
        dex
        bne @ArrangeInnerLoop
        iny
        ldx #4
        lda @SM1+1
        clc
        adc #4
        sta @SM1+1
        lda @SM1+2
        adc #$00
        sta @SM1+2
        cpy #3
        bcc @ArrangeOuterLoop        

                        ;$02 to $04 for Dividend (16bit.8bit), also output!
                        ;$05 to $06 for Divisor (16bit.)
                        ;$07 to $0a for Div-Routine
                        ;$10 to $1B for sorted point data
                        ;$1C to $2e for Variables

        lda #$00        ;LS = P1x
        sta @LS         ;LE = P1x
        sta @LE         ;LSg = P2x
        lda @P1x       
        sta @LS+1       
        sta @LE+1       
        lda @P1x+1
        sta @LS+2
        sta @LE+2
        lda @P2x
        sta @LSg
        lda @P2x+1
        sta @LSg+1

        lda @P2y        ;f = (P2y-P1y)/(P3y-P1y)
        sec
        sbc @P1y
        sta Dividend+1 ;Always Remember: Dividend+0 is after decimal point!
        lda @P2y+1
        sbc @P1y+1
        sta Dividend+2
        lda @P3y        
        sec
        sbc @P1y
        sta Divisor 
        lda @P3y+1
        sbc @P1y+1
        sta Divisor+1
        lda #$00
        sta Dividend
        jsr Divide
        lda Dividend
        sta Multiplier
        sta @f
        stx Multiplicand ;This is tacky af, but x should always be 0 after Divide

                        ;$02 to $08 for Multiply
                        ;$09 to $0a for Buffer of P3x*f

        lda @P3x        ;LEg = P1x*(1-f)+P3x*f
        sta Multiplicand+1
        lda @P3x+1
        sta Multiplicand+2
        jsr Multiply
        lda Product+1
        sta $09
        lda Product+2
        sta $0a
        lda #$00
        sta Multiplicand
        lda @P1x
        sta Multiplicand+1
        lda @P1x+1
        sta Multiplicand+2
        lda #$00        ;calculate 1-f
        sec
        sbc @f
        sta Multiplier
        jsr Multiply                
        lda Product+1
        clc
        adc $09
        sta @LEg
        tax
        lda Product+2
        adc $0a
        sta @LEg+1
        tay

        txa       ;if (LSg > LEg) {
        sec       ;       Switch LSg and LEg
        sbc @LSg  ;}
        tya
        sbc @LSg+1
        bcs @LSgBelowLEg
        ldx @LSg
        lda @LEg
        stx @LEg
        sta @LSg
        ldx @LSg+1
        lda @LEg+1
        stx @LEg+1
        sta @LSg+1
@LSgBelowLEg

         
        lda #$00        ;MLS = (|LSg-P1x|)/(P2y-P1y)
        sta Dividend    ;if (LSg < P1x){
        sta @MLSn       ;       MLSn = true
        lda @LSg        ;}
        sec
        sbc @P1x
        tax
        lda @LSg+1
        sbc @P1x+1
        tay
        bcc @P1xAboveLSg
        stx Dividend+1
        sty Dividend+2
        jmp @P1xBelowLSg
@P1xAboveLSg
        lda #$01
        sta @MLSn
        stx @f  ;factor is not used anymore, so I can do this. Remember: Recycling is good!
        lda #$00
        sec
        sbc @f
        sta Dividend+1
        sty @f
        lda #$00
        sbc @f
        sta Dividend+2
@P1xBelowLSg
        lda @P2y
        sec
        sbc @P1y
        sta Divisor
        lda @P2y+1
        sbc @P1y+1
        sta Divisor+1
        jsr Divide
        lda Dividend
        sta @MLS
        lda Dividend+1
        sta @MLS+1
        lda Dividend+2
        sta @MLS+2


        lda #$00        ;MLE = (|LEg-P1x|)/(P2y-P1y)
        sta Dividend    ;if (LEg < P1x){
        sta @MLEn       ;        MLEn = true
        lda @LEg        ;}
        sec
        sbc @P1x
        tax
        lda @LEg+1
        sbc @P1x+1
        tay
        bcc @P1xAboveLEg
        stx Dividend+1
        sty Dividend+2
        jmp @P1xBelowLEg
@P1xAboveLEg
        lda #$01
        sta @MLEn
        stx @f  ;factor is not used anymore, so I can use it yet again.
        lda #$00
        sec
        sbc @f
        sta Dividend+1
        sty @f
        lda #$00
        sbc @f
        sta Dividend+2
@P1xBelowLEg
        jsr Divide      ;P2y-P1y is already in Divisor, so we just leave it there
        lda Dividend
        sta @MLE
        lda Dividend+1
        sta @MLE+1
        lda Dividend+2
        sta @MLE+2

        lda @P1y+1     ;CL = ($8000 < P1y < $80c7) (cl is lowest 8 bits)
        cmp #$80       ;CL is set to first line to be drawn ($c7 is 199 in decimal, as the screen is 200 pixels high)
        bcs @CLbig
        lda #$00
        sta @CL

        ldy #$00        ;This should be seen more as an insert.
@AdjustLSLE             ;The Code Here adjusts LS and LE if P1y is above the screen.
        lda #$00
        sec
        sbc @P1y
        sta BigMultiplicand
        lda #$80
        sbc @P1y+1                      
        sta BigMultiplicand+1
        lda @MLS,y
        sta BigMultiplier
        lda @MLS+1,y
        sta BigMultiplier+1
        lda @MLS+2,y
        sta BigMultiplier+2
        jsr BigMultiply             
        lda @MLSn,y
        bne @SubFromLS
        lda @LS,y
        clc
        adc BigProduct
        sta @LS,y
        lda @LS+1,y
        adc BigProduct+1
        sta @LS+1,y
        lda @LS+2,y
        adc BigProduct+2
        sta @LS+2,y
        jmp @LSAddDone
@SubFromLS
        lda @LS,y
        sec
        sbc BigProduct
        sta @LS,y
        lda @LS+1,y
        sbc BigProduct+1
        sta @LS+1,y
        lda @LS+2,y
        sbc BigProduct+2
        sta @LS+2,y
@LSAddDone
        tya
        bne @CLDone
        ldy #3
        jmp @AdjustLSLE

@CLBig
        beq @CLProbablyOnScreen
        rts                             ;If P1y is below screen, then there is nothing to draw
@CLProbablyOnScreen
        lda @P1y
        cmp #$c8
        ldx #$ff ;this is just to clear the zero flag
        bcs @CLBig
        sta @CL
@CLDone

        lda @P2y+1     ;LL = ($8000 < P1y < $80c7-CL), first Calculated is LastLine,
        cmp #$80       ;then Lines Left is Calculated A-CL
        bcs @LLbig
        jmp @TopMainFinished ;if P2y is above screen, then there is no top part to draw
@LLBig
        beq @LLProbablyOnScreen
        lda #$c7
        jmp @LLDone
@LLProbablyOnScreen
        lda @P2y
        cmp #$c8
        ldx #$ff ;this is just to clear the zero flag
        bcs @LLBig
@LLDone
        sec
        sbc @CL
        sta @LL

@TopMainLoop

TODO Use SM-Code with MLSn/MLEn for speed Boost   

        jsr @DrawLine

        ldy @MLSn       ;Move Line Start and Line End according to MLS and MLE
        bne @MLSnSet    
        lda @LS
        clc
        adc @MLS
        sta @LS
        lda @LS+1
        adc @MLS+1
        sta @LS+1
        lda @LS+2
        adc @MLS+2
        sta @LS+2
        jmp @MLSDone
@MLSnSet
        lda @LS
        sec
        sbc @MLS
        sta @LS
        lda @LS+1
        sbc @MLS+1
        sta @LS+1
        lda @LS+2
        sbc @MLS+2
        sta @LS+2
@MLSDone
        ldy @MLEn       ;now set LE = LE +/- MLE
        bne @MLEnSet
        lda @LE
        clc
        adc @MLE
        sta @LE
        lda @LE+1
        adc @MLE+1
        sta @LE+1
        lda @LE+2
        adc @MLE+2
        sta @LE+2
        jmp @MLEDone
@MLEnSet
        lda @LE
        sec
        sbc @MLE
        sta @LE
        lda @LE+1
        sbc @MLE+1
        sta @LE+1
        lda @LE+2
        sbc @MLE+2
        sta @LE+2
@MLEDone

        inc @CL
        dec @LL
        bne @TopMainLoop

TODO If there's no Top part, LSg and LEg are weird

@TopMainFinished                

        lda #$00
        sta @LS
        sta @LE

        lda @LSg
        sta @LS+1
        lda @LSg+1
        sta @LS+2
        lda @LEg
        sta @LE+1
        lda @LEg+1
        sta @LE+2
        
        lda @P3x
        sta @LSg
        sta @LEg
        lda @P3x+1
        sta @LSg+1
        sta @LEg+1

        lda #$00        ;MLS = (|LSg-LS|)/(P3y-P2y)
        sta Dividend    ;if (LSg < LS){
        sta @MLSn       ;       MLSn = true
        lda @LSg        ;}
        sec
        sbc @LS+1
        tax
        lda @LSg+1
        sbc @LS+2
        tay
        bcc @LSAboveLSg
        stx Dividend+1
        sty Dividend+2
        jmp @LSBelowLSg
@LSAboveLSg
        lda #$01
        sta @MLSn
        stx @f  ;factor is not used anymore, so I can do this. Remember: Recycling is good!
        lda #$00
        sec
        sbc @f
        sta Dividend+1
        sty @f
        lda #$00
        sbc @f
        sta Dividend+2
@LSBelowLSg
        lda @P3y
        sec
        sbc @P2y
        sta Divisor
        lda @P3y+1
        sbc @P2y+1
        sta Divisor+1
        jsr Divide
        lda Dividend
        sta @MLS
        lda Dividend+1
        sta @MLS+1
        lda Dividend+2
        sta @MLS+2

        lda #$00        ;MLE = (|LEg-LE|)/(P3y-P2y)
        sta Dividend    ;if (P3x < LEg){
        sta @MLEn       ;        MLEn = true
        lda @LEg        ;}
        sec
        sbc @LE+1
        tax
        lda @LEg+1
        sbc @LE+2
        tay
        bcc @LEAboveLEg
        stx Dividend+1
        sty Dividend+2
        jmp @LEBelowLEg
@LEAboveLEg
        lda #$01
        sta @MLEn
        stx @f  ;factor is not used anymore, so I can use it yet again.
        lda #$00
        sec
        sbc @f
        sta Dividend+1
        sty @f
        lda #$00
        sbc @f
        sta Dividend+2
@LEBelowLEg
        jsr Divide      ;P3y-P2y is already in Divisor, so we just leave it there
        lda Dividend
        sta @MLE
        lda Dividend+1
        sta @MLE+1
        lda Dividend+2
        sta @MLE+2

        lda @P3y+1      ;Calculate LL
        cmp #$80
        beq @LLProbablyOnScreen2
        lda #200
        jmp @LLDone2
@LLProbablyOnScreen2
        lda @P3y
        cmp #201
        bcc @LLDone2
        lda #200
@LLDone2
        sec
        sbc @CL
        sta @LL

@BottomMainLoop

TODO Use SM-Code with MLSn/MLEn for speed Boost   

        jsr @DrawLine

        ldy @MLSn       ;Move Line Start and Line End according to MLS and MLE
        bne @MLSnSet2    
        lda @LS
        clc
        adc @MLS
        sta @LS
        lda @LS+1
        adc @MLS+1
        sta @LS+1
        lda @LS+2
        adc @MLS+2
        sta @LS+2
        jmp @MLSDone2
@MLSnSet2
        lda @LS
        sec
        sbc @MLS
        sta @LS
        lda @LS+1
        sbc @MLS+1
        sta @LS+1
        lda @LS+2
        sbc @MLS+2
        sta @LS+2
@MLSDone2
        ldy @MLEn       ;now set LE = LE +/- MLE
        bne @MLEnSet2
        lda @LE
        clc
        adc @MLE
        sta @LE
        lda @LE+1
        adc @MLE+1
        sta @LE+1
        lda @LE+2
        adc @MLE+2
        sta @LE+2
        jmp @MLEDone2
@MLEnSet2
        lda @LE
        sec
        sbc @MLE
        sta @LE
        lda @LE+1
        sbc @MLE+1
        sta @LE+1
        lda @LE+2
        sbc @MLE+2
        sta @LE+2
@MLEDone2

        inc @CL
        dec @LL
        bne @BottomMainLoop

        rts


@FirstCol        = $04 ;First Column to write to
@ColsRemaining   = $05 ;Columns remaining
@LastDot         = $06 ;Last Dot to color
@StartMaskBuffer = $07 ;Start Mask Buffer


@DrawLine               ;$04 is start character No. ,$05 is how many bytes to write
        lda #>Bitmap    ;$02/$03 is set to screen address of line start
        sta $03         ;we first set $02 according to LS
        lda @LS+2
        cmp #$80
        bcs @FirstCharBig
        lda #0                  ;because we start at 0th horizontal character
        tay     ;for later use
        sta $02
        sta @FirstCol
        jmp @FirstCharDone
@FirstCharBig
        beq @FirstCharProbablyOnScreen
        rts ;testing
@FirstCharProbablyOnScreen
        lda @LS+1
        cmp #160
        ldx #$ff ;this is just to clear the zero flag
        bcs @FirstCharBig
        tay     ;for later use
        and #%11111100          ;because we start at A'th horizontal character
        asl
        php
        sta $02
        tax
        lda $03
        adc #$00
        sta $03
        txa
        plp
        ror
        lsr
        lsr
        sta @FirstCol
@FirstCharDone

        lda @LE+2       ;ColsRemaining is first set to last Column
        cmp #$80
        bcs @LastCharBig
        rts                     ;because we end at 0th horizontal character
@LastCharBig
        beq @LastCharProbablyOnScreen
        lda #160
        sta @LastDot
        lda #40
        jmp @LastCharDone
@LastCharProbablyOnScreen
        lda @LE+1
        cmp #160
        ldx #$ff ;this is just to clear the zero flag
        bcs @LastCharBig
        sta @LastDot
        lsr
        lsr
@LastCharDone
        sec
        sbc @FirstCol
        sta @ColsRemaining

        lda @CL
        and #%00000111
        clc
        adc $02
        sta $02
        lda @CL
        and #%11111000
        asl
        asl
        asl
        tax
        clc
        adc $02
        sta $02
        lda $03
        adc #$00
        sta $03
        txa
        asl
        asl
        clc
        adc $02
        sta $02
        lda $03
        adc #$00
        sta $03
        lda @CL
        lsr
        lsr
        lsr
        tax
        clc
        adc $03
        sta $03
        txa
        lsr
        lsr
        clc
        adc $03
        sta $03
        
        tya             ;shift for smooth edges 
        and #%00000011  ;(look a good bit further above to see where we got y from)
        bne @DoStartEdgeShift
        lda #$ff
        jmp @NoStartEdgeShift
@DoStartEdgeShift
        tax
        lda #$ff
@StartEdgeShiftLoop
        lsr
        lsr
        dex
        bne @StartEdgeShiftLoop
@NoStartEdgeShift

        ldy @ColsRemaining
        beq @OneCharLine
        and @P
        ldy #$00
        sta ($02),y
        lda $02
        clc
        adc #8
        sta $02
        lda $03
        adc #$00
        sta $03
        ldx @ColsRemaining
        dex                     ;Because we've already written one column
        beq @EndEdgeShift
        jmp @MainDraw
@OneCharLine
        sta @StartMaskBuffer
        lda @LastDot
        and #%00000011
        bne @OneCharLineShift
        rts
@OneCharLineShift
        sta @FirstCol ;Contents of this register are not used anymore at this point
        lda #4
        sec
        sbc @FirstCol
        tax
        lda #$ff
@OneCharLineLoop
        asl
        asl
        dex
        bne @OneCharLineLoop
        and @StartMaskBuffer
        and @P
        ldy #$00
        sta ($02),y
        rts

@MainDraw
        lda @P
        sta ($02),y
        lda $02
        clc
        adc #8
        sta $02
        lda $03
        adc #$00
        sta $03
        dex
        bne @MainDraw
@EndEdgeShift
        lda @LastDot      ;shift Last Column left for smooth edges 
        and #%00000011
        bne @DoEndEdgeShift
        rts
@DoEndEdgeShift
        sta @FirstCol ;Contents of this register are not used anymore at this point
        lda #4
        sec
        sbc @FirstCol
        tax
        lda #$ff
@EndEdgeShiftLoop
        asl
        asl
        dex
        bne @EndEdgeShiftLoop
        and @P
        ldy #$00
        sta ($02),y
        rts

        
@P1x = $10 ;Point 1, X-Coord    16bit.
@P1y = $12 ; (...)              (...)
@P2x = $14
@P2y = $16
@P3x = $18
@P3y = $1a



;The Variables:

@LS    =$1c  ;Line Start      16bit.8bit
@LE    =$1f  ;Line End        16bit.8bit
@MLS   =$22  ;Movement LS     16bit.8bit
@MLE   =$25  ;Movement LE     16bit.8bit
@MLSn  =$28  ;MLS negative    Lowest bit
@LSg   =$29  ;LS goal         16bit.            ;LSg is here for the 3-byte difference(hint below)
@MLEn  =$2b  ;MLE negative    Lowest bit
@f     =$2c  ;factor          .8bit
@LEg   =$2d  ;LE goal         16bit.
@LL    =$2f  ;Lines Left      8bit.
@CL    =$30  ;Current Line    8bit.
@P     =$31  ;Pattern         8bit

;Important: LS-LE, MLS-MLE and MLSn-MLEn must all be exactly 3 bytes apart!


MP1x
        byte 50         ;<P1x
        byte $80        ;>P1x
MP1y
        byte 10         ;<P1y
        byte $80        ;>P1y
MP2x
        byte 150        ;<P2x
        byte $80        ;>P2x
MP2y
        byte 10        ;<P2y
        byte $80        ;>P2y
MP3x
        byte 64        ;<P3x
        byte $80        ;>P3x
MP3y
        byte 200        ;<P3y
        byte $80        ;>P3y


todo MLSn Problem


Divide

Dividend = $02          ;$02 to $04 for Dividend (16bit.8bit), also output!
Divisor = $05           ;$05 to $06 for Divisor (16bit.)                        
                        ;$07 to $0a for randoom shyte
        lda $05
        clc
        adc $06
        bne @DivisorNotZero
        sta Dividend
        sta Dividend+1
        sta Dividend+2
        rts

@DivisorNotZero
        LDA #0      ;Initialize REM to 0
        STA @REM
        STA @REM+1
        STA @REM+2
        LDX #24     ;There are 24 bits in NUM1
@L1     ASL @NUM1    ;Shift hi bit of NUM1 into REM
        ROL @NUM1+1  
        ROL @NUM1+2
        ROL @REM
        ROL @REM+1
        ROL @REM+2
        LDA @REM
        SEC         ;Trial subtraction
        SBC @NUM2
        TAY
        LDA @REM+1
        SBC @NUM2+1
        STA $0a
        LDA @REM+2
        SBC #$00
        BCC @L2      ;Did subtraction succeed?
        STA @REM+2   ;If yes, save it
        LDA $0a
        STA @REM+1
        STY @REM
        INC @NUM1    ;and record a 1 in the quotient
@L2     DEX
        BNE @L1
        rts


@NUM1 = $02
@NUM2 = $05
@REM = $07


Multiply                ;16bit. * .8bit = 16bit.

Multiplicand = $02      ;$02 to $04 for Multiplicand (16bit.8bit)
Multiplier = $05        ;$05        for Multiplier (.8bit)                        
Product = $06           ;$06 to $08 for Output (16bit.8bit)

        lda #$00
        sta Product
        sta Product+1
        sta Product+2
        ldx #8
@loop
        lsr Multiplicand+2
        ror Multiplicand+1
        ror Multiplicand
        asl Multiplier
        bcc @NoAdding
        lda Product
        clc
        adc Multiplicand
        sta Product
        lda Product+1
        adc Multiplicand+1
        sta Product+1
        lda Product+2
        adc Multiplicand+2
        sta Product+2
@NoAdding
        dex
        bne @loop
        rts


BigMultiply             ;16bit. * 16bit.8bit = 16bit.8bit
                        ;zeropage up to $10 is safe to use
BigMultiplicand = $02      ;$02 to $03 for Multiplicand (16bit.)
BigMultiplier = $04        ;$04 to $06 for Multiplier (16bit.8bit)                        
BigProduct = $07           ;$07 to $09 for Output (16bit.8bit)
@ProductSmall = $0a        ;0a         for smallest byte of Product (not meant for output)

        lda #$00
        sta BigProduct
        sta BigProduct+1
        sta BigProduct+2
        ldx #16
@loop
        lsr BigMultiplicand+1
        ror BigMultiplicand
        bcc @NoAdding
        lda BigProduct
        clc
        adc BigMultiplier
        sta BigProduct
        lda BigProduct+1
        adc BigMultiplier+1
        sta BigProduct+1
        lda BigProduct+2
        adc BigMultiplier+2
        sta BigProduct+2
@NoAdding
        asl BigMultiplier
        rol BigMultiplier+1
        rol BigMultiplier+2
        dex
        bne @loop
        rts






ColorRamInit
        ldx #>ColorRam
        stx @SM1+2
        ldx #$00
        ldy #$04        ;Becuase ColorRam is $0400 bytes long
@loop1
@SM1
        sta ColorRam,x
        inx
        bne @loop1
        inc @SM1+2
        dey
        bne @loop1
        rts

CharRamInit
        ldx #>CharRam
        stx @SM1+2
        ldx #$00
        ldy #$04        ;Becuase CharRam is $0400 bytes long
@loop1
@SM1
        sta CharRam,x
        inx
        bne @loop1
        inc @SM1+2
        dey
        bne @loop1
        rts

BitmapInit
        ldx #>Bitmap
        stx @SM1+2
        ldx #$00
        ldy #$20        ;Becuase Bitmap is $2000 bytes long
@loop1
@SM1
        sta Bitmap,x
        inx
        bne @loop1
        inc @SM1+2
        dey
        bne @loop1
        rts

        