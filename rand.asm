; 11-bit lfsr
; выход:
; HL - число от 1 до 2047
rnd11:
		lxi h,1
		mov a, h
		rrc \ rrc
		xra h
		ani 1           ; bit 10 xor bit 8
		dad h
		ora l
		mov l, a        ; lsb = bits 10 xor 8
		mov a, h
		ani $7
		mov h, a
		shld rnd11+1
		ret

; Псевдослучайное 8-битное число с периодом 256 по отношению: X[1] = X[0] * 5 + 7
; I: -
; O: A=RND
; M: HL, AF
rnd8:		lxi	h, rnd8val
		mov	a,m
		add	a
		add	a
		add	m
		adi	7
		mov	m,a
		ret
rnd8val         db      1
