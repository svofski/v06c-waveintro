;AY emulator on VI53 v0.1
;Компилировать в TASM - A Table Driven Cross Assembler for the MSDOS* Environment (tasm 3.01 или 3.2)
;Иван Городецкий 04.05.2009
;ПО "Счетмаш" 1988-1990


		; a = psg register number
		; e = data
WRTPSG:
		push	h
		push	d
		lxi	h, AYmainJmpTable

WRTPSG_dispatch:
		ani	0Fh
		add	a
		call	add_hl_a
		mov	d, m
		inx	h
		mov	h, m
		mov	l, d
		pchl
; End of function WRTPSG

; ---------------------------------------------------------------------------
AYmainJmpTable:	.dw AY00,AY01,AY02,AY03
		.dw AY04,AY05,AY06,AY07
		.dw AY08,AY09,AY10,AY11
		.dw AY12,AY13,AY1415,AY1415
; ---------------------------------------------------------------------------
;нижние	8 бит частоты канала A

AY00:
		mov	a, e
		sta	AY_R0
		call	SetFreqTimerCh0
		jmp	AY1415
; ---------------------------------------------------------------------------
;верхние 4 бита	частоты	канала A

AY01:
		mov	a, e
		sta	AY_R1
		call	SetFreqTimerCh0
		jmp	AY1415
;Задаем	частоту	для канала 0 таймера

; =============== S U B	R O U T	I N E =======================================


SetFreqTimerCh0:
                lda     AY_R8       ; только если канал включен
                cpi     0011b
                rc
                ;lda     AY_R7
                ;ani     001b
                ;rnz                 ; никаких частот, если тон не разрешен

		lxi	h, AY_R0
		call	FreqAY_to_VI53
		mov	a, l
		out	0Bh
		mov	a, h
		out	0Bh
		ret
; End of function SetFreqTimerCh0

;Преобразуем частоту для AY в частоту для ВИ53

; =============== S U B	R O U T	I N E =======================================


FreqAY_to_VI53:
		mov	a, m
		inx	h
		mov	h, m
		mov	l, a
		mvi	a,00001111b
		ana	h
		mov	h, a

Not0Freq:
		push	b
		mov	b,h
		mov	c,l
		dad	h
		mov	e, l
		mov	d, h
		dad	h
		dad	d
		dad	h	;*12
		dad	b	;*13
		mov	a,b
		ora	a
		rar
		mov	b,a
		mov	a,c
		rar
		mov	c,a
		dad	b	;*13.5
		pop	b
		ret
; End of function FreqAY_to_VI53

; ---------------------------------------------------------------------------
;нижние	8 бит частоты канала B

AY02:
		mov	a, e
		sta	AY_R2
		call	SetFreqTimerCh1
		jmp	AY1415
; ---------------------------------------------------------------------------
;верхние 4 бита	частоты	канала B

AY03:
		mov	a, e
		sta	AY_R3
		call	SetFreqTimerCh1
		jmp	AY1415

; =============== S U B	R O U T	I N E =======================================

SetFreqTimerCh1:
                lda     AY_R9       ; только если канал включен
                cpi     0011b
                rc
                lda     AY_R7
                ani     010b
                rnz                 ; никаких частот, если тон не разрешен


		lxi	h, AY_R2
		call	FreqAY_to_VI53
		mov	a, l
		out	0Ah
		mov	a, h
		out	0Ah
		ret

; ---------------------------------------------------------------------------
;нижние	8 бит частоты канала C

AY04:
		mov	a, e
		sta	AY_R4
		call	SetFreqTimerCh2
		jmp	AY1415
; ---------------------------------------------------------------------------
;верхние 4 бита	частоты	канала C

AY05:
		mov	a, e
		sta	AY_R5
		call	SetFreqTimerCh2
		jmp	AY1415
;Задаем	частоту	для канала 2 таймера

; =============== S U B	R O U T	I N E =======================================


SetFreqTimerCh2:
                lda     AY_R10       ; только если канал включен
                cpi     0011b
                rc
                lda     AY_R7
                ani     100b
                rnz                 ; никаких частот, если тон не разрешен

		lxi	h, AY_R4
		call	FreqAY_to_VI53
		mov	a, l
		out	9
		mov	a, h
		out	9
		ret
; End of function SetFreqTimerCh2

; ---------------------------------------------------------------------------
;Нижние	8 бит управления периодом огибающей

AY11:
		jmp	AY1415
; ---------------------------------------------------------------------------
;Верхние 8 бит управления периодом огибающей
AY12:
		mov	a, e
		sta	AY_R12
		jmp	AY1415
; ---------------------------------------------------------------------------
;Выбор формы огибающей
AY13:
		mvi	a,00001111b
		ana	e
		sta	AY_R13
		jmp	AY1415
; ---------------------------------------------------------------------------
;Управление частотой генератора шума
AY06:
		mvi	a,00011111b
		ana	e
		sta	AY_R6
		lxi	h,NoisePeriod
		call	add_hl_a
		mov	a,m
		cpi	255			;шум с очень маленьким периодом (что индицируется задержкой 255) обрабатывается отдельной процедурой
		jz	PrepareNoiseHigh
		sta	NoiseDelay-1
		mvi	a,00011111b
		ana	e
		lxi	h,NoiseLength
		call	add_hl_a
		mov	a,m
		rlc
		sta	NoiseLoop-2
		lxi	h,NoiseNormal
		shld	NoiseDispatch+1
		jmp	AY1415

PrepareNoiseHigh:
		lxi	h,NoiseHigh
		shld	NoiseDispatch+1
		jmp	AY1415

NoisePeriod:
		.db 0 ;?33			;0	-> тишина ?3,46 кГц (д.б. ?3,44)
		.db 0,0,0			;1-3	-> тишина (д.б. 110-36,67)
		.db 255,255,255,255	;4-7	-> 16.321 кГц (д.б. 27,5-15,71)
		.db 1				;8	-> 13,171 кГц (д.б. 13,75)
		.db 2				;9	-> 12,109 кГц (д.б. 12,22)
		.db 3				;10   -> 11,205 кГц (д.б. 11)
		.db 4				;11   -> 10,427 кГц (д.б. 10)
		.db 6				;12	-> 9,156 кГц (д.б. 9,17)
		.db 7				;13	-> 8,629 кГц (д.б. 8,46)
		.db 9				;14	-> 7,74 кГц (д.б. 7,86)
		.db 10			;15	-> 7,36 кГц (д.б. 7,33)
		.db 12			;16	-> 6,703 кГц (д.б. 6,88)
		.db 13			;17	-> 6,417 кГц (д.б. 6,47)
		.db 14			;18	-> 6,154 кГц (д.б. 6,11)
		.db 15			;19	-> 5,911 кГц (д.б. 5,79)
		.db 17			;20	-> 5,48 кГц (д.б. 5,5)
		.db 18			;21	-> 5,287 кГц (д.б. 5,24)
		.db 20			;22	-> 4,939 кГц (д.б. 5)
		.db 21			;23	-> 4,782 кГц (д.б. 4,78)
		.db 22			;24	-> 4,634 кГц (д.б. 4,58)
		.db 24			;25	-> 4,365 кГц (д.б. 4,4)
		.db 25			;26	-> 4,242 кГц (д.б. 4,23)
		.db 26			;27	-> 4,125 кГц (д.б. 4,07)
		.db 28			;28	-> 3,91 кГц (д.б. 3,93)
		.db 29			;29	-> 3,811 кГц (д.б. 3,79)
		.db 30			;30	-> 3,717 кГц (д.б. 3,67)
		.db 32			;31	-> 3,541 кГц (д.б. 3,55)

NoiseLength:
		.db 23,88,88,88,88,88,88,88,88,81,75,69,61,57,52,49,45,43,41,39,36,35,33,32,31,29
		.db 28,27,26,25,25,24

; ---------------------------------------------------------------------------
;Управление каналами

AY07:
		call	AY07sub
;Регистры портов ввода/вывода

AY1415:
		pop	d
		pop	h
;		pop	psw
;		jmp	0A18Ah	;только для RMPPlayer!!!

subAY07_000:
		ret

; =============== S U B	R O U T	I N E =======================================


AY07sub:
		mov	a, e
                sta     AY_R7
		ani	111000b
		cpi	111000b		; шума нет ни по одному	каналу?
		jnz	Noise		; есть шумовые каналы
		lxi	h, AY_R7_Noise
		mvi	m, 0		; если нет шума, то пишем 0

MergNoisAndTon:
		rrc
		rrc
		rrc			; задвинули признаки включения/выключения шумовых каналов
					; в младшие 3 бита
		ora	e		; объединили признаки вкл/выкл шумовых и тоновых каналов
					; в мл.	3х битах
		mov	e, a
		lda	AY_R7_Process
		xra	e		; смотрим, какие каналы	изменились
		lxi	h, AY07JmpTab
		ani	111b
		jmp	WRTPSG_dispatch
; ---------------------------------------------------------------------------

Noise:
		sta	AY_R7_Noise
		jmp	MergNoisAndTon
; End of function AY07sub

; ---------------------------------------------------------------------------
AY07JmpTab:	.dw subAY07_000,subAY07_001,subAY07_010,subAY07_011
		.dw subAY07_100,subAY07_101,subAY07_110,subAY07_111
;обработка канала A

; =============== S U B	R O U T	I N E =======================================


subAY07_001:
		mov	a, e
		sta	AY_R7_Process
; End of function subAY07_001


; =============== S U B	R O U T	I N E =======================================


TimerCh0:
		ani	001b
		jz	SetFreqTimerCh0
		mvi	a, 36h		; выключаем канал 0 таймера
		out	8
		ret
; End of function TimerCh0

;обработка канала B

; =============== S U B	R O U T	I N E =======================================


subAY07_010:
		mov	a, e
		sta	AY_R7_Process
; End of function subAY07_010


; =============== S U B	R O U T	I N E =======================================


TimerCh1:
		ani	010b
		jz	SetFreqTimerCh1
		mvi	a, 76h		; выключаем канал 1 таймера
                                        ; 01          counter 1
                                        ;   11        lsb first
                                        ;     011     sq gen
                                        ;        0    no bcd
		out	8
		ret
; End of function TimerCh1

; ---------------------------------------------------------------------------
;обработка канала C

subAY07_100:
		mov	a, e
		sta	AY_R7_Process

; =============== S U B	R O U T	I N E =======================================


TimerCh2:
		ani	100b
		jz	SetFreqTimerCh2
		mvi	a, 0B6h		; выключаем канал 2 таймера
		out	8
		ret
; End of function TimerCh2

; ---------------------------------------------------------------------------

subAY07_011:
		call	subAY07_001
		jmp	subAY07_010
; ---------------------------------------------------------------------------

subAY07_101:
		call	subAY07_001
		jmp	subAY07_100
; ---------------------------------------------------------------------------

subAY07_110:
		call	subAY07_010
		jmp	subAY07_100
; ---------------------------------------------------------------------------

subAY07_111:
		call	subAY07_001
		jmp	subAY07_110
; ---------------------------------------------------------------------------
;Громкость канала A

AY08:
		mov	a, e
		ani	10000b	; проверка установки огибающей для канала A
		sta	AY_R8
		jnz	Envelope	; переход на обработку огибающей
		mov	a, e
		ani	1111b		; выделили громкость
                sta     AY_R8
		cpi	3
		mvi	a, 1111b	; выключение канала
		jc	SetTimerCh0	; если громкость A<3 (0-2) то выключить	канал
		mvi	a, 0		; не выключать канал

SetTimerCh0:
		call	TimerCh0
		jmp	AY1415
; ---------------------------------------------------------------------------

Envelope:
		lda	AY_R12
		rrc
		rrc
		rrc
		ani	11110b		; сдвинули и выделили старшие 4	бита периода огибающей
		inr	a
		sta	EnvPeriod
		sta	EnvPeriodCount
		call	SetFreqTimerCh0
		jmp	AY1415
;Звуковая (шумовая) процедура, вызываемая по прерываниям

; =============== S U B	R O U T	I N E =======================================


NoiseProcInt:
;проверяем тип огибающей
		lda	AY_R13
		ani	00001111b
		lxi	h,Env
		call	add_hl_a
		mov	a,m
		ora	a
		jnz	NoiseProcess	;если "бесконечная" огибающая, то переходим на отработку шума
;если огибающая "конечная", то обрабатываем ее период
		lda	EnvPeriod
		ora	a
		jz	NoiseProcess	; если период огибающей	0, то переходим на отработку шума
		lxi	h, EnvPeriodCount
		dcr	m
		jnz	NoiseProcess
		xra	a
		sta	EnvPeriod	; обнуляем период огибающей
;глушим каналы
		lda	AY_R8
		ora	a
		jz	EnvCh1
		mvi	a, 36h	;гасим канал 0
		out	8
EnvCh1:
		lda	AY_R9
		ora	a
		jz	EnvCh2
		mvi	a, 76h	;гасим канал 1
		out	8
EnvCh2:
		lda	AY_R10
		ora	a
		jz	NoiseProcess
		mvi	a, 0B6h	;гасим канал 2
		out	8

NoiseProcess:
ret
;		lda	EnvPeriod
;		ora	a
;		rz			; если период огибающей	0, то уходим
		lda	AY_R7_Noise
		ora	a
		rz			; если шумовых каналов нет, то уходим
NoiseDispatch:
		jmp	NoiseNormal
NoiseNormal:
		lda	NoiseDelay-1
		ora	a
		rz			; если период шума нехороший (что индицируется задержкой 0), то уходим
		lxi	d, 0			;здесь будет количество повторов
NoiseLoop:
		mvi	b,0			;8	здесь будет задержка, рассчитанная при обработке R6
NoiseDelay:	dcr	b			;8
		jnz	NoiseDelay		;12
;8+20*x
		lhld	NoiseReg		;20
		lda	NoiseReg+2		;20
		dad	h			;12
		ral				;4
		sta	NoiseReg+2		;16
		jnc	NoXor			;12
		mvi	a,00000010b		;8
		xra	h			;4
		mov	h,a			;8
		mvi	a,10000000b		;8
		xra	l			;4
		mov	l,a			;8
		shld	NoiseReg		;20
		mvi	a,1			;8
		out	0			;12
		dcx	d			;8
		mov	a, e			;8
		ora	d			;8
		jnz	NoiseLoop		;12
		ret
;20*3+16+12*4+8*8+4*3=60+16+48+64+12=200
NoXor:
		mvi	a,00000000b
		xra	h
		mov	h,a
		mvi	a,00000000b
		xra	l
		mov	l,a
		shld	NoiseReg
		mvi	a,0
		out	0			;12
		dcx	d			;8
		mov	a, e			;8
		ora	d			;8
		jnz	NoiseLoop		;12
		ret

NoiseHigh:
		mvi	e,109*2
NoiseHighLoop:
		lhld	NoiseReg		;20
		lda	NoiseReg+2		;20
		dad	h			;12
		ral				;4
		sta	NoiseReg+2		;16
		jnc	HighNoXor		;12
		mvi	a,00000010b		;8
		xra	h			;4
		mov	h,a			;8
		mvi	a,10000000b		;8
		xra	l			;4
		mov	l,a			;8
		shld	NoiseReg		;20
		mvi	a,1			;8
		out	0			;12
		dcr	e			;8
		jnz	NoiseHighLoop	;12
;184
		ret
HighNoXor:
		mvi	a,00000000b		;8
		xra	h			;4
		mov	h,a			;8
		mvi	a,00000000b		;8
		xra	l			;4
		mov	l,a			;8
		shld	NoiseReg		;20
		mvi	a,0			;8
		out	0			;12
		dcr	e			;8
		jnz	NoiseHighLoop	;12
		ret

;табличка, в которой "конечным" огибающим соответствует 0
Env:		.db 0,0,0,0
		.db 0,0,0,0
		.db 1,0,1,1
		.db 1,1,1,0

NoiseReg:	.db 1,255,255
; End of function NoiseProcInt

; ---------------------------------------------------------------------------
;Громкость канала B

AY09:
		mov	a, e
		ani	10000b
		sta	AY_R9
		jnz	Envelope
		mov	a, e
		ani	1111b
                sta     AY_R9
		cpi	0011b
		mvi	a, 1111b
		jc	SetTimerCh1
		mvi	a, 0

SetTimerCh1:
		call	TimerCh1
		jmp	AY1415
; ---------------------------------------------------------------------------
;Громкость канала C

AY10:
		mov	a, e
		ani	10000b
		sta	AY_R10
		jnz	Envelope
		mov	a, e
		ani	1111b
                sta     AY_R10
		cpi	11b
		mvi	a, 0Fh
		jc	SetTimerCh2
		mvi	a, 0

SetTimerCh2:
		call	TimerCh2
		jmp	AY1415
; ---------------------------------------------------------------------------
AY_R0:		.db 1
AY_R1:		.db 1
AY_R2:		.db 1
AY_R3:		.db 1
AY_R4:		.db 1
AY_R5:		.db 1
AY_R6:		.db 1
AY_R7:          .db 0
;храним признак активности огибающей в соответствующем канале
AY_R8:		.db 0
AY_R9:		.db 0
AY_R10:		.db 0

AY_R12:		.db 1
AY_R13:		.db 0
AY_R7_Process:	.db 0FFh
					; обработанное значение	R7
					; в младших 3х битах признаки вкл/выкл каналов
EnvPeriod:		.db 0
AY_R7_Noise:	.db 0
					; в битах 3-5 содержит признаки
					; вкл/выкл шумовых каналов
EnvPeriodCount:	.db 0

; =============== S U B	R O U T	I N E =======================================


add_hl_a:
		add	l
		mov	l, a
		rnc
		inr	h
		ret
; End of function add_hl_a


		.end
