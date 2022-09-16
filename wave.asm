                .project intro.rom
                .tape v06c-rom
                .org $100
                
WAVE_PLANE      equ $80
MAX_SCALE       equ 78
SCALE_STEP      equ MAX_SCALE / 16

FISH_Y          equ $40

TEXT_Y          equ 0xA0

                
start:
                di
		xra	a
		out	10h
		lxi	sp, 100h
		mvi	a, 0C3h
		sta	0
		lxi	h,Restart
		shld	1

		mvi	a, 0C9h
		sta	38h

                call ayvi53_stfu
                call precalc_scales
Restart:
                di
		xra	a
		out	10h
		lxi	sp, 100h

                lxi sp, $100

		mvi	a, 0C9h
		sta	38h
                call ayvi53_stfu
                
                lxi h, colors_main + 15
                call colorset
                call cls

                call fill_bottom  ; fill bottom of the bowl
                call init_wave    ; init previous wave value
Restart_loop:
                di
                call cls_c0       ; fast clear texts
                xra a
                sta dwav_phase    ; phase = 0
                sta dwav_voffs    ; vertical offset = 0
                sta global_frm    ; frame = 0
                sta waves_enabled ; waves disabled (at start)
                sta waves_finishing ; not finishing
                sta waves_finished ; enabled, just no change in amplitude
                sta fish_enabled  ; fish disabled at start
                sta msgseq_end_flag ; message sequence enabled
                sta fish_wraparound_flag
                mvi a, $1e      ; fish appears in this column
                sta fish_col
                mvi a, $ff    ; msb of initial scale increment (-128)
                sta ampl_inc_sign

                mvi a, $34
                sta dwav_voffs_alt ; voffs = inr

                call msgseq_init

                ; gigachad

                ; загружаем и прокачиваем начало песенки
                lxi h, song_1
                call gigachad_init
                call gigachad_enable
                call gigachad_precharge

                ; обработчик прерывания с гигачадом 
                mvi a, $c3
                sta $38
                lxi h, interrupt
                shld $39
                
                ei

                ; the fish will be painted in motion when enabled
                ;call drawfish

                mvi a, $60          ; putchar draws to backing store $6000
                sta _putchar_msb

                ;;; main loop
                lxi h, costab_s + 128 * 20  ; initial phase = zero waves
bob_1                
                mvi c, 20                   ; number of steps
bob_2           
                lda waves_finishing
                ora a
                jz bob_22
                
                ; finishing, check that the wave is at 0
                mvi a, (costab_s + 128 * 20)>>8
                cmp h
                jnz bob_22
                mvi a, (costab_s + 128 * 20) & 255
                cmp l
                jnz bob_22
                ; finally reached zero amplitude
                ;xra a
                ;sta waves_enabled
                mvi a, $ff
                sta waves_finished 
                ; disable, but paint the zero amplitude wave first
                jmp bob_222
bob_22:
                lda waves_enabled
                ora a
                jz bob_2
bob_222:
                push b
                push h
                shld wave_coeff         ; current wave scale
                call diffwave
                call msgseq_frame

bob_l1:
                pop h
                pop b
bob_3
                lda waves_finished
                ora a
                jz next_amplitude
                lda dwav_voffs_alt
                ora a
                jz Restart_loop  ; all done, restart
                jmp bob_1 ; finishing..

                ;jnz bob_1  ; finished -> no amplitude increment/decrement
next_amplitude:
ampl_inc_sign   equ $+2
                lxi d, -128
                dad d
                dcr c
                jnz bob_2
                ; invert increment
                lda ampl_inc_sign  
                cma
                sta ampl_inc_sign  
                jmp bob_1
                ;;;;;;;;;;;;;;;;;
                ;;;;;;;;;;;;;;;;;
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;;

fill_bottom:    mvi c, 32
                lxi h, (WAVE_PLANE << 8) + $80
                mvi b, $ff
fb_1:
                mov m, b
                dcr l
                jnz fb_1
                inr h
                mvi l, $80
                dcr c
                jnz fb_1
                ret
                
init_wave       lxi h, prevwave
                lxi b, $8000
iw_l1                
                mov m, b
                inx h
                dcr c 
                jnz iw_l1
                ret

gigachad_wrap_hook:
                lda msgseq_end_flag
                rar
                rnc
                call ayvi53_stfu
                mvi a, $ff
                sta waves_finishing
                call gigachad_disable
                stc
                ret

interrupt:      push psw
                push b
                push d
                push h


                ;mvi a, 15
                ;out $c

                call gigachad_frame
                ;call ay_send_user
                lda waves_finishing
                ora a
                cz ay_send_vi53

                ;call NoiseProcInt ; useless, but it would break messages if i remove it

                ;mvi a, 1
                ;out $c

                lda fish_enabled
                ora a
                cnz dumbshift
                ;call movefish

                ;mvi a, 0
                ;out $c

                lxi h, global_frm
                mov a, m
                inr a
                mov m, a
                cpi 200
                jnz intr_l1
                ;;;mvi a, 1
                ;lda waves_finishing
                ;cma
                mvi a, $ff
                sta waves_enabled
intr_l1:
                pop h
                pop d
                pop b
                pop psw
                ei
                ret

global_frm      db 0
waves_enabled   db 0
waves_finishing db 0        ; $ff when waves should stop waving
waves_finished  db 0        ; $ff when waves finished waving (but still enabled)
fish_enabled    db 0
msgseq_frm      db 0
msgseq_fadectr  db 0
msgseq_ptr      dw 0
msgseq_y        db 0
msgseq_end_flag db 0        ; end of message sequence
msgseq_fish_sync db 0       ; waiting for the fish
fish_wraparound_flag db 0

; 24 is approx the fish line

m_hello         db 70, 1, 0
                db 70,2,    '        GIVE IT UP FOR...       ', 0
                db 1, 5,    '  #####   ##   ##  ##### #####  ', 0
                db 1, 6,    '  ##  ##  ##   ##  ##       ##  ', 0
                db 1, 7,    '  ##  ##  ##   ##  ##      ##   ', 0
                db 1, 8,    '  #####   ##  ###  ####   ###   ', 0
                db 1, 9,    '  ##   ## ## # ##     ##    ##  ', 0
                db 1, 10,   '  ##   ## ###  ##     ##    ##  ', 0
                db 25,11,   '  ######  ##   ##  ####  ####   ', 0


                db 30, 16, ' AY/VI53 EMULATOR FISH SAYS HI!', 0
                db 1, 255   ; fish enabler
                db 1,2,     '        GIVE IT UP FOR...        ', 0
                db 1,20,    ' AYVI53 IVAGOR   GIGACHAD16 SVO', 0
                db 1,2,0
                db 1,2,     '        GIVE IT UP FOR...        ', 0
                db 1,29,    ' MUSIC|UNIT-5 REWRITTEN BY KURT ', 0
                db 50,2,0

                db 1, 16, 0
                db 1, 20, 0
                db 170, 29, 0

                db 250,2,     '    PLAYED BY SECOND TO NONE    ', 0   
                ; 254 = fish synchronizer
                db 1, 254
                db 25, 24,   '   DESASTER  ERRORSOFT          ', 0
                db 1, 254
                db 25, 24,   '   FIXEL  FROG                  ', 0
                db 1, 254
                db 25, 24,   '   IVAGOR   KAN SOFT            ', 0
                db 1, 254
                db 25, 24,   '   LAFROMM31   MANWE            ', 0
                db 1, 254
                db 25, 24,   '   METAMORPHO  NZEEMIN          ', 0
                db 1, 254
                db 25, 24,   '     PYK   TNT23                ', 0
                db 1, 254
                db 254, 24,   '   RETROTECHSQUAD              ', 0
                db 254, 1, 0
                db 2,  2, 0
                db 1,  5, 0
                db 1,  6, 0
                db 1,  7,     '       VI53 SECOND TO NONE      ', 0
                db 1,  8, 0
                db 1,  9,     '  A NOISY INTRO FOR UNEXPANDED  ', 0
                db 1,  10, 0
                db 1,  11,    '          VECTOR-06C            ', 0
                db 1, 12, 0
                db 1, 28,     '           SVO  2022            ', 0
                db 250,  16, 0
                db 250,  16, 0
                db 250,  16, 0
                db 250,  16, 0
                db 250,  16, 0
                db 250,  16, 0

                db 0, 0

msgseq_init:    
                lxi h, m_hello
                shld msgseq_ptr
                xra a
                sta msgseq_frm
                sta msgseq_fadectr
                ret

msgseq_frame:    
                lxi h, msgseq_fadectr   ; если фейд, продолжаем фейд
                mov a, m
                ora a
                jnz msgseq_fade
                
                lxi h, msgseq_frm       ; задержка
                mov a, m
                ora a
                jz msgseq_next          ; дотикали, следующее сообщение

                dcr m                   ; счетчик задержки -= 1, выход
                ret

msgseq_next:
                lda msgseq_fish_sync
                ora a
                jz msgseq_next_nosync
                lda fish_wraparound_flag
                ora a
                rz
                xra a
                sta msgseq_fish_sync
msgseq_next_nosync:
                ; берем следующее сообщение, печатаем, ставим задержку
                lhld msgseq_ptr
                mov a, m
                sta msgseq_frm
                mvi a, 32
                sta msgseq_fadectr
                inx h

                mov a, m
                cpi 255   ; fish enabler
                jnz mseq_next_l1
                mvi a, 1
                sta fish_enabled
                inx h
                jmp mseq_next_l2
mseq_next_l1:
                cpi 254   ; fish synchronizer
                jnz mseq_next_normal
                xra a
                sta fish_wraparound_flag
                mvi a, 1
                sta msgseq_fish_sync
                inx h
                jmp mseq_next_l2
mseq_next_normal:
                ral \ ral \ ral \ cma \ inr a

                sta msgseq_y
                push h
                mvi h, 0
                mov l, a
                call gotoxy
                pop h
                inx h

                mov a, m
                ora a
                cz   wipestr
                cnz  puts
                inx h
                mov a, m

                ora a ; 0 признак конца секвенции, ставим флажок
                jz msgseq_end
mseq_next_l2:
                shld msgseq_ptr
                ret


                db 0, 0

msgseq_init:    
                lxi h, m_hello
                shld msgseq_ptr
                xra a
                sta msgseq_frm
                sta msgseq_fadectr
                ret

msgseq_frame:    
                lxi h, msgseq_fadectr   ; если фейд, продолжаем фейд
                mov a, m
                ora a
                jnz msgseq_fade
                
                lxi h, msgseq_frm       ; задержка
                mov a, m
                ora a
                jz msgseq_next          ; дотикали, следующее сообщение

                dcr m                   ; счетчик задержки -= 1, выход
                ret

msgseq_next:
                ; берем следующее сообщение, печатаем, ставим задержку
                lhld msgseq_ptr
                mov a, m
                sta msgseq_frm
                mvi a, 32
                sta msgseq_fadectr
                inx h

                mov a, m
                cpi 255   ; fish enabler
                jnz mseq_next_l1
                mvi a, 1
                sta fish_enabled
                inx h
                jmp mseq_next_l2
mseq_next_l1:
                ral \ ral \ ral \ cma \ inr a

                sta msgseq_y
                push h
                mvi h, 0
                mov l, a
                call gotoxy
                pop h
                inx h

                mov a, m
                ora a
                cz   wipestr
                cnz  puts
                inx h
                mov a, m

                ora a ; 0 признак конца секвенции, ставим флажок
                jz msgseq_end
mseq_next_l2:
                shld msgseq_ptr
                ret

msgseq_end:   
                ; ставим признак конца секвенции, но не смещаем указатель
                mvi a, 1
                sta msgseq_end_flag
                ret

                
                ; делаем фейд 32 кадра
msgseq_fade     dcr m                   ; счетчик фейдa -= 1

fade_text_frame2:
                mvi c, 8
ftf2_l1
                call rnd8   ; result in A and rnd8val
                mov d, a
                mvi a, 7
                ana d
                mov e, a
                xra d       ; high 5 bit = column
                rar \ rar \ rar
                adi $60
                mov h, a
                xri $a0
                mov d, a

                lda msgseq_y
                sui 7
                add e
                mov l, a
                mov e, a

                mov a, m
                stax d

                dcr c
                jnz ftf2_l1
                ret

                

;fade_text_init:       
;                ret
;
;fade_text_frame:
;
;ff_bubu:
;                call rnd11 ; clobbers a, h, l
;                
;                lxi d, (TEXT_Y - 7) << 8
;                dad d
;                
;                mov e, h
;
;                mvi b, PixelMask >> 8
;                mvi a, 7
;                ana l       ; x
;                mov c, a    ; bc = &pixelmask
;
;                xra l
;                rar \ rar \ rar
;                adi $60   ; source plane $6000
;                mov h, a
;                xri $a0
;
;                mov d, a  ; de = $c000[xy]
;                mov l, e
;
;                ldax b    ; pixel mask
;
;                ana m     ; pixel & src
;                xchg
;                ora m     ; (pixel & src) | screen
;                mov m, a
;
;                ret
;
;                jmp ff_bubu
;
      

                
                .org $100 + . & 0xff00
prevwave:       ds 256


diffwave:
                mvi a, WAVE_PLANE
                sta vseg_column
                
                mvi d, 0        ; x = 0
                mvi a, 11000000b
                sta vseg_mask
dwav_1:
dwav_phase      equ $+1
                mvi a, 0
                add d
                ora a
                rar             ; cos arg = (x + phase) / 2
wave_coeff      equ $+1
                lxi h, costab_s
                add l
                mov l, a
                
dwav_voffs      equ $+1
                mvi a, 0        ; vertical offset
                add m           ; + cos(arg)
                mov e, a        ; e = cos(arg)

                push d
                call vseg
                pop d

                ; rotate  pixel mask
                lxi h, vseg_mask
                mov a, m
                rrc \ rrc 
                mov m, a
                
                jnc dwav_samecol
                ; increment display column when mask rolls over
                lxi h, vseg_column
                inr m
dwav_samecol:
                
                inr d           ; x += 2
                inr d
                jnz dwav_1
                
                
                ;;;;;;;
                
                ; make funky phase shifts
                ; this is a very sensitive part
                lxi h, dwav_phase
                lda prevwave
                sui $80
                rar
                add m
                ;adi 2          ; extra offset, but can't say if i can see the difference
                mov m, a
                
                ; bounce up / down
                lxi h, dwav_voffs
dwav_voffs_alt:
                inr m           ; SELFMOD inr/dcr

                lda waves_finishing
                ora a
                jz dwav_notf

                ; finishing: disable voffs change when at 0
                xra a
                ora m
                jnz dwav_notf

                sta dwav_voffs_alt  ; set increment/decrement to nop
                ret

dwav_notf:
                mvi a, 25
                cmp m
                jz dwav_todcr
                mvi a, -25
                cmp m
                jz dwav_toinr
                ret
dwav_todcr      mvi a, $35      ; dcr m
                sta dwav_voffs_alt
                ret
dwav_toinr      mvi a, $34      ; inr m
                sta dwav_voffs_alt
                ret
                

                ; fill vertical segment x = d, to = e, prevwave[d] = prev
vseg:
                mvi b, prevwave >> 8
                mov c, d
vseg_column     equ $+1
                mvi d, $80
                ; d = column, e = y

                ; y count = e - yprev (yrev very)
                ldax b                  ; a = prev
                cmp e                   ; prev x current
                jm vseg_noswap
                rz                      ; equal means nothing to do

                ; swap top and bottom and clear pixels from bottom to top
                mov l, a
                sub e                   ; a = y_count (fill height)
                ; jump offset = end - y_count * 4
                ;ani $3f \
                ral \ ral 
                mov h, a                ; h = y_count * 4

                mov a, e
                stax b                  ; store prev[x]
                mov e, l

                xra a   ; a = vseg_clear_end & 255
                sub h
                mov l, a
                mvi h, (vseg_clear_end >> 8) - 1

                lda vseg_mask
                cma
                mov c, a
                pchl

vseg_noswap:    ; set pixels from top to bottom            
                ; a = bottom, e = top, a < e
                mov l, a
                mov a, e
                stax b                  ; store prev[x]
                sub l                   ; top - bottom = count
                
                ; jump offset = end - y_count * 4
                ;ani $3f \ 
                ral \ ral
                cma
                ;adi (vseg_set_end & 255) + 1
                mov l, a
                mvi h, (vseg_set_end >> 8) - 1
vseg_mask       equ $+1
                mvi c, 0
                pchl

                .org $100 + . & 0xff00
                .org . + $98
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
                ldax d \ ora c \ stax d \ dcr e
vseg_set_end
                ret
                
                .org $100 + . & 0xff00
                .org . + $98
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
                ldax d \ ana c \ stax d \ dcr e
vseg_clear_end
                ret
                
                
                
cls:
                lxi h, $8000
                mvi b, 0
cls_l1:                
                mov m, b
                inx h
                mov m, b
                inx h
                mov a, l
                ora h
                jnz cls_l1
                ret

cls_c0:         ; clear only c000
                di
                lxi h, 0
                dad sp
                shld clsc0_sp
                lxi sp, 0xc000+0x2000
                lxi d, 0
                ; total of 
                xra a
cls_c0_l1:
                push d \ push d \ push d \ push d
                push d \ push d \ push d \ push d
                push d \ push d \ push d \ push d
                push d \ push d \ push d \ push d
                dcr a
                jnz cls_c0_l1

clsc0_sp        equ $+1
                lxi sp, 0
                ret

colorset:
                ei
                hlt
colorset_nowait:
                mvi	a, 88h
		out	0
		mvi	c, 15
colorset1:	mov	a, c
		out	2
		mov	a, m
		out	0Ch
		dcx	h
		out	0Ch
		out	0Ch
		dcr	c
		out	0Ch
		out	0Ch
		out	0Ch
		jp	colorset1
		mvi	a,255
		out	3
                mvi a, 4
                out 2
                ret


drawfish: 
                lxi h, $d000 + FISH_Y
                lxi d, fishb0
                call drawspr
                lxi h, $f000 + FISH_Y
                lxi d, fishb1
                call drawspr
                ret

maybe_wipe_fish:
                mvi a, $ff
                sta fish_wraparound_flag
                lda msgseq_end_flag
                ora a
                rz
                xra a
                sta fish_enabled
                ; time to let go of the fish
                lxi d, fishz0
                mvi h, $c0
                mvi l, FISH_Y

                lxi b, $0208
mwf_l2:
                xra a
mwf_l1:
                mov m, a \ inr h \ mov m, a \ dcr l
                mov m, a \ dcr h \ mov m, a \ dcr l
                dcr c
                jnz mwf_l1
                mvi a, $20
                add h
                mov h, a
                mvi l, FISH_Y
                dcr b
                jnz mwf_l2
              
                ret

drawfish_a      
                mov a, m
                cpi $1e
                jp maybe_wipe_fish
                ;rp

                lxi d, fisha0
                mvi a, $c0
                add m
                inr a
                mov h, a
                mvi l, FISH_Y
                push h
                call drawspr
                pop h
                mvi a, $20
                add h
                mov h, a
                lxi d, fisha1
                jmp drawspr
                ;call drawspr
                ;jmp $

drawfish_b      
                mov a, m
                cpi $1e
                jp maybe_wipe_fish
                ;rp

                lxi d, fishb0
                mvi a, $c0
                add m
                inr a
                mov h, a
                mvi l, FISH_Y
                push h
                call drawspr
                pop h
                mvi a, $20
                add h
                mov h, a
                lxi d, fishb1
                jmp drawspr
                ;call drawspr
                ;jmp $
                
drawspr:
                mvi c, 2
drawspr_l1
                ldax d \ mov m, a \ inx d \ inr h
                ldax d \ mov m, a \ inx d \ dcr h \ dcr l
                ldax d \ mov m, a \ inx d \ inr h
                ldax d \ mov m, a \ inx d \ dcr h \ dcr l
                ldax d \ mov m, a \ inx d \ inr h
                ldax d \ mov m, a \ inx d \ dcr h \ dcr l
                ldax d \ mov m, a \ inx d \ inr h
                ldax d \ mov m, a \ inx d \ dcr h \ dcr l
                ldax d \ mov m, a \ inx d \ inr h
                ldax d \ mov m, a \ inx d \ dcr h \ dcr l
                ldax d \ mov m, a \ inx d \ inr h
                ldax d \ mov m, a \ inx d \ dcr h \ dcr l
                ldax d \ mov m, a \ inx d \ inr h
                ldax d \ mov m, a \ inx d \ dcr h \ dcr l
                ldax d \ mov m, a \ inx d \ inr h
                ldax d \ mov m, a \ inx d \ dcr h \ dcr l

                dcr c
                jnz drawspr_l1

                ret
                

                ; ORDER IMPORTANT
fish_col_frac   db 1
fish_col        db $0f
shiftctr        db 0

                ; fish swimming
dumbshift:
                lda fish_col
                adi $c0
                mov b, a
                inr a
                ani $1f
                adi $c0
                mov d, a

                inr a 
                ani $1f
                adi $c0
                mov h, a

                mvi a, FISH_Y
                mov l, a \ mov e, a \ mov c, a
                call oneshift

                lda fish_col
                adi $e0
                mov b, a \ inr a \ ani $1f \ adi $e0 \ mov d, a
                           inr a \ ani $1f \ adi $e0 \ mov h, a

                mvi a, FISH_Y
                mov l, a \ mov e, a \ mov c, a
                call oneshift

                lxi h, fish_col_frac
                mov a, m
                rlc
                mov m, a
                rnc

                inx h       ; hl = &fish_col
                mov a, m
                dcr a       ; previous column
                ani $1f
                mov m, a

                ; switch sprite
                rar ; lsb
                jc  drawfish_a
                jmp drawfish_b
                ;ret

oneshift:
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                ora a \ mov a, m \ ral \ mov m, a 
                           ldax d \ ral \ stax d
                           ldax b \ ral \ stax b \ dcr l \ dcr e \ dcr c
                
                ret

                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;;
                ;;      P R E C A L C
                ;;
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

precalc_scales:
                mvi a, MAX_SCALE               ; initial scale
                sta scale_mul
                lxi h, costab_s
                shld scale_dst
presc_1:
                call scale_cos
                
                lda scale_mul
                sui SCALE_STEP                   ; scale step
                jm presc_inv            ; copy the same upside down to further buffers
                sta scale_mul
                lhld scale_dst
                lxi d, 128
                dad d
                shld scale_dst
                jmp presc_1

                ; make negative scales by copying and inverting positive
                ; inv[0] = -normal[last], inv[1] = -normal[last-1] etc
presc_inv:
                lhld scale_dst
                push h                  ; last destination = source
                lxi d, 128
                dad d
                xchg                    ; de = dst
                pop h                   ; hl = src
                push h                  ; also on stack

                mvi b, 16
invdst_l2:
                mvi c, 128              ; one scale size 128
invdst_l1:
                mvi a, $80              
                sub m
                adi $7f
                stax d                  ; *dst = 128 - src + 128
                inx h
                inx d
                dcr c
                jnz invdst_l1
                
                pop h                   ; current dst
                push b
                lxi b, -128             ; dst = previous scale
                dad b
                pop b
                push h
                
                dcr b
                jnz invdst_l2
                pop h
                ret

                ; scale cos table from source in costab to scale_dst
                ; scale_dst = destination
scale_cos:
                lxi d, costab
scale_dst       equ $+1
                lxi h, costab_s
                
                push h
                push h

                mvi c, 64       ; process 64 values, second 64 will be mirrored
scale_cos_1:                
                ldax d
                push h
                push d
                push b
                mov h, a
scale_mul       equ $+1
                mvi l, 30
                mov a, l
                rar 
                cma
                adi $80
                push psw
                
                call mul8x8             
                pop psw
                add h
                
                pop b
                pop d
                pop h
                mov m, a
                inx d
                inx h
                dcr c
                jnz scale_cos_1
                
                ; expand second half of the table
                pop h
                lxi d, 127
                dad d
                mov b, h
                mov c, l
                pop h
excos_1:
                mov a, m
                stax b
                inx h
                dcx b
                mov a, l
                cmp c
                jm excos_1
                ret


                ; HL=H*E h/t ivagor
mul8x8:
                mov e, l
		xra a
		mov l,a
		mov d,a
		cma
mul88_1:
		dad h
		jnc mul88_2
		dad d
mul88_2:
		add a
		jm mul88_1
		ret


                .org 0x100 + . & 0xff00
PixelMask:
		.db 11000000b
		.db 01000000b
		.db 00110000b
		.db 00010000b
		.db 00001100b
		.db 00000100b
		.db 00000011b
		.db 00000001b
                
floor0          equ 363q ; darker
floor1          equ 373q ; lighter
floor2          equ 0
pic1            equ 156q  ; желтушный
pic2            equ 114q  ; малиновый
pic3            equ 377q  ; блѣ

colors0:        .ds 16

colors_main:
                .db floor0, pic2, pic3, pic1
                .db floor2, pic2, pic3, pic1
                .db floor1, pic2, pic3, pic1
                .db floor1, pic2, pic3, pic1

costab          .db 255, 255, 254, 254, 253, 251, 250, 248, 245, 243, 240, 237, 234, 230, 226, 222, 218, 213, 208, 203, 198, 193, 188, 182, 176, 170, 165, 158, 152, 146, 140, 134, 128, 121, 115, 109, 103, 97, 90, 85, 79, 73, 67, 62, 57, 52, 47, 42, 37, 33, 29, 25, 21, 18, 15, 12, 10, 7, 5, 4, 2, 1, 1, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GIGACHAD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include fish.inc
fishz0: ds 32   ; empty sprite for wiping
.include VI53.asm
.include rand.asm   ; rnd11
.include font8x8.asm

; songe
song_1:         dw songA_00, songA_01, songA_02, songA_03, songA_04, songA_05, songA_06
                dw songA_07, songA_08, songA_09, songA_10, songA_11, songA_12, songA_13
.include songe.inc

.include gigachad16.inc

costab_s        .equ gigachad_end

