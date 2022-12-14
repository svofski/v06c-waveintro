;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;             GIGACHAD - 16          ;;;;;
;;;;;  Packed AY/YM player by svofski  ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Based on ZX0 8080 decoder by Ivan Gorodetsky - OLD FILE FORMAT v1 
; Based on ZX0 z80 decoder by Einar Saukas
;
; This player unpacks 14 concurrent streams of AY register dumps.
; Each tick it calls a task that unpacks 16 bytes of data. There are
; 14 tasks in total. 

; The song should be prepared as 14 streams of zx0 streams packed using
; a 256-byte window. See ym6break.py.
;
; Source YM6 file should be interleaved. The easiest way to convert a pt3
; song into YM6 is by using AY_Emul by Sergey Bulba. I used version v2.9 32.
; Arkos Tracker II also can export interleaved YM6 files.
;
; In essence this is a minimal RTOS kernel with cooperative multitasking.
; 14 tasks unpack 14 streams in 16-byte portions. To get a full register
; set that could be sent to the AY, each task must be executed first.
; 
; During normal playback ay_send is called every frame. All 14 tasks 
; are cycled every 16 frames, so 2 frames out of 16 are skipped.
; 
; The kernel is a hack, but it can be adapted to execute any tasks.


OPCODE_STC      equ $37
OPCODE_ORA_A    equ $B7

; total number of scheduler tasks                
n_tasks         equ 14

; task stack size (20 should be enough, erring on the safe side)
task_stack_size equ 22

                ; pointer to the current stream in song array used by create_song_tasks
create_sptr     dw 0
                ; saved pointer to song arrayfor looping
recreate_sptr   dw 0
                ; finished tasks counter, used to detect song end
dzx0_finish_ctr db 0

                ;; Used internally by gigachad_init
                ;; Do not call this procedure directly.
                ;;
                ;; create 14 tasks for song
                ;; hl = address of array of 14 pointers to packed song data (song_00, song_01, ...song_13)
create_song_tasks:
                xra a
                sta dzx0_finish_ctr
                shld create_sptr
                shld recreate_sptr
                
                lxi b, buffer00
                lxi h, stack_00 + task_stack_size

create_song_tasks_L1:
                push h
                lhld create_sptr
                mov e, m \ inx h \ mov d, m \ inx h
                shld create_sptr
                pop h
                
                push b
                push h
                call dzx0_create
                pop h
                ; task_stack += task_stack_size 
                mvi c, task_stack_size & 255
                mvi b, task_stack_size >> 8
                dad b   
                
                ; task_buffer += 256
                pop b
                inr b

                inr a
                cpi 14
                jnz create_song_tasks_L1

                ret

                ;; gigachad_init
                ;; Initialize player: create tasks and init scheduler.
                ;; hl = array of 14 pointers to packed song data
                ;;      [song_00, song_01, ... song_13]
gigachad_init:
                call create_song_tasks
                call scheduler_init
                call gigachad_disable

                mvi a, -15
                sta ay_nline
                mvi a, -1
                sta gigachad_nfrm

                mvi a, OPCODE_ORA_A
                sta gigachad_wrap_flag

                ret
                
                ;; enable playback
gigachad_enable:
                xra a       ; a = opcode("nop")
                jmp $+5
                ;; disable playback
gigachad_disable:
                mvi a, $c9  ; a = opcode("ret")
                sta gigachad_frame
                ret
                
                ;; gigachad_precharge
                ;; Silently process first 16 frames so that all data
                ;; are available for playback.
                ;; Can only be called after gigachad_init
gigachad_precharge
                lxi h, gigachad_nfrm
                mov a, m
                inr a
                ani $f
                mov m, a
                cpi 14
                jp $+6
                call scheduler_tick
                lxi h, ay_nline
                inr m
                mvi a, -1
                cmp m
                jnz gigachad_precharge                
                ret

                ;; gigachad_frame
                ;; Calls scheduler_tick 14 out of 16 frames.
                ;; May call ay_send, or let user call ay_send_user
gigachad_frame:
                ret       ; SELFMOD: enable/disable switch: nop / ret
gigachad_wrap_flag:
                ora a     ; SELFMOD: stc = wraparound, ora a = normal playback
                jc gigachad_wrap

                lxi h, gigachad_nfrm
                mov a, m
                inr a
                ani $f
                mov m, a
                cpi 14
                jp $+6
                call scheduler_tick
                lxi h, ay_nline
                inr m

                ; USER_CALLS_AY_SEND
                ;call ay_send

                ; all tasks finished?
                lda dzx0_finish_ctr
                cpi n_tasks
                rm
                
                ; all tasks have finished, but we still have 16 frames to burn
                mvi a, OPCODE_STC
                sta gigachad_wrap_flag
                mvi a, 16
                sta gigachad_wrap_ctr
                ret

                ; end of song: finish playback and restart
                ; by recreating all tasks and starting over
gigachad_wrap:
                ; burn unpacked remainder
                ;lxi h, ay_nline
                ;inr m
                ;call ay_send
                ;lxi h, gigachad_wrap_ctr
                ;dcr m
                ;rnz

                ; user-defined, sets carry if we don't want song to restart
                call gigachad_wrap_hook
                rc

                ;; load song pointers
                mvi a, OPCODE_ORA_A
                sta gigachad_wrap_flag

                mvi a, -15
                sta ay_nline
                mvi a, -1
                sta gigachad_nfrm

                lhld recreate_sptr
                call create_song_tasks
                call gigachad_precharge
                ret


                ; current line in decode buffer
                ; regs would be r0 = buffer00[ay_nline], r1 = buffer00[ay_nline + 256], etc
ay_nline        db 0
gigachad_nfrm   db 0
gigachad_wrap_ctr db 0

                ;
                ; AY-3-8910 register ports
                ;
ayctrl          equ $15
aydata          equ $14
                
ay_outde
           	mov a, d
                out ayctrl
                mov a, e
                out aydata
                ret
                
                ; utility: silence the AY
ay_stfu         lxi d, $0700
                call ay_outde
                lxi d, $0800
                call ay_outde
                lxi d, $0900
                call ay_outde
                lxi d, $0a00
                jmp ay_outde
                
                ; utility: make AY noise
ay_noise	
                lxi d, $07c7 ; noise enable on channel A
                call ay_outde
                lxi d, $0803 ; volume pretty low on channel A
                call ay_outde
                lxi d, $0905 ; volume pretty low on channel B
                call ay_outde
                lxi d, $0a03 ; volume pretty low on channel C
                jmp ay_outde

                ; utility: make AY noise louder
ay_noise_louder
                lxi d, $07c7 ; noise enable on channel A
                call ay_outde
                lxi d, $0806 ; volume pretty low on channel A
                call ay_outde
                lxi d, $090c ; volume pretty low on channel B
                call ay_outde
                lxi d, $0a06 ; volume pretty low on channel C
                jmp ay_outde
		;ret


                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ay_send_vi53:
                lxi h, ay_nline
                ; send from buffers to AY regs
                ; m = line number 
                ; reg13 (envelope shape) is special: $ff means no change / don't write
                mvi d, 13
                mov c, m                
                mvi b, (buffer00 >> 8) + 13 ; last column
                
                ldax b
                cpi $ff
                jz ayvi53_send_L2           ; no touchy fishy
ayvi53_send_L1                
                ldax b  
                mov e, a
                mov a, d
                call WRTPSG

ayvi53_send_L2                
                dcr b                   ; prev column
                dcr d
                jp ayvi53_send_L1
                ret


ayvi53_stfu:
                mvi a, $36
                out 8
                mvi a, $76
                out 8
                mvi a, $b6
                out 8
                ret
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


ay_send_user:
                lxi h, ay_nline
                ; send from buffers to AY regs
                ; m = line number 
                ; reg13 (envelope shape) is special: $ff means no change / don't write
ay_send         
                mvi e, 13
                ;lxi b, ay_line+13
                mov c, m                
                mvi b, (buffer00 >> 8) + 13 ; last column
                
                ldax b
                cpi $ff
                jz ay_send_L2           ; no touchy fishy
ay_send_L1                
                mov a, e
                out ayctrl
                ldax b
                out aydata
ay_send_L2                
                dcr b                   ; prev column
                dcr e
                jp ay_send_L1
                ret
#ifndef RSOUND
ay_send_user:
                lxi h, ay_nline
                ; send from buffers to AY regs
                ; m = line number 
                ; reg13 (envelope shape) is special: $ff means no change / don't write
ay_send         
                mvi e, 13
                ;lxi b, ay_line+13
                mov c, m                
                mvi b, (buffer00 >> 8) + 13 ; last column
                
                ldax b
                cpi $ff
                jz ay_send_L2           ; no touchy fishy
ay_send_L1                
                mov a, e
                out ayctrl
                ldax b
                out aydata
ay_send_L2                
                dcr b                   ; prev column
                dcr e
                jp ay_send_L1
                ret
#else
                ; R-Sound 
ay_send_user:
                lxi h, ay_nline
                ; send from buffers to AY regs
                ; m = line number 
                ; reg13 (envelope shape) is special: $ff means no change / don't write
ay_send         
                mvi a, $88
                out 4

                mvi e, 13
                ;lxi b, ay_line+13
                mov c, m                
                mvi b, (buffer00 >> 8) + 13 ; last column
                
                ldax b
                cpi $ff
                jz ay_send_L2           ; no touchy fishy
ay_send_L1                
                ; ay reg = e
                mov a, e
                out 6
                mvi a, 6 \ out 5 \ xra a \ out 5  ; strobe ctrl

                ldax b
                out 6                   ; data
                mvi a, 4 \ out 5 \ xra a \ out 5  ; strobe ctrl
ay_send_L2                
                dcr b                   ; prev column
                dcr e
                jp ay_send_L1
                ret
#endif                
                
                ;;
                ;; gigachad rtos kernel
                ;;

                ;; scheduler_init()
                ;; sets initial context_ptr and enables scheduler_tick()
scheduler_init:
                lxi h, context
                shld context_ptr
                xra a
scheduler_init_L1:                
                sta scheduler_tick    ; enable the scheduler
                ret

                ;; scheduler_deinit()
                ;; disable scheduler_tick()
scheduler_deinit:
                mvi a, $c9            ; disable the scheduler
                jmp scheduler_init_L1
                
                ;; scheduler_tick()
                ;;
                ;; Calls next task in order.
                ;;
scheduler_tick: 
                ret         ; SELFMOD: ret: disable / nop: enable
                lxi h, 0
                dad sp
                shld sched_sp
                lhld context_ptr
                mov e, m \ inx h \ mov d, m ; de = &context[n]
                xchg
                sphl
                
                ; restore task context and return into it
                pop h
                pop d
                pop b
                pop psw
                ret

                ;; sched_yield()
                ;;
                ;; Yield to next task and return from scheduler.
sched_yield:
                lxi h, 0 
                dad sp
                xchg                    ; de = task context
                lhld context_ptr        ; hl = context[n]
                mov m, e \ inx h \ mov m, d \ inx h
                mvi a, context_end >> 8
                cmp h
                jnz sched_ret
                mvi a, context_end & 255
                cmp l
                jnz sched_ret
sched_restart_:
                lxi h, context
sched_ret
                shld context_ptr
sched_sp        equ $+1
                lxi sp, 0
                ret
                
                ;; dzx0 task yields after producing every 16 octets
dzx0_yield:     push psw
                push b
                push d
                push h
                jmp sched_yield

                ;; dzx0_create()
                ;;
                ;; Create a dzx0 streaming unpacker task.
                ;;
                ;; a = task number (0..n_tasks-1)
                ;; hl = task stack end
                ;; bc = dst buffer
                ;; de = stream source
dzx0_create:                   
                shld crea_loadsp
                lxi h, crea_b+1
                mov m, c \ inx h \ mov m, b \ inx h \ inx h
                mov m, e \ inx h \ mov m, d
                
                lxi h, 0
                dad sp
                shld dzx0_create_sp
                
                lxi d, context  ; context[0]
                mov l, a
                mvi h, 0
                dad h
                dad d           ; hl = &context[a]
                shld crea_ctx+1 ; will save task sp here
crea_loadsp     equ $+1
                lxi sp, 0
crea_b:         lxi b, 0
crea_d:         lxi d, 0

                ; create task entry point within its context
                lxi h, dzx0
                push h
                push psw
                push b
                push d
                push h
                lxi h, 0
                dad sp
crea_ctx:       shld 0                  ; save sp in task context
dzx0_create_sp  equ $+1
                lxi sp, 0
                ret                     ; this is a normal return

                ;; dzx0()
                ;; 
                ;; Unpack zx0 stream packed with 256-byte sized window.
                ;; Yields every 16 bytes.
dzx0:
		lxi h,0FFFFh            ; tos=-1 offset?
		push h
		inx h
		mvi a,080h
dzx0_literals:  ; Literal (copy next N bytes from compressed file)
		call dzx0_elias         ; hl = read_interlaced_elias_gamma(FALSE)
;		call dzx0_ldir          ; for (i = 0; i < length; i++) write_byte(read_byte()
		push psw
dzx0_ldir1:
		ldax d
		stax b
		inx d
		inr c           ; stay within circular buffer

		; yield every 16 bytes
		mvi a, 15
		ana c
		cz dzx0_yield 
		;call dzx0_yield
		dcx h
		mov a,h
		ora l
		jnz dzx0_ldir1
		pop psw
		add a

		jc dzx0_new_offset      ; if (read_bit()) goto COPY_FROM_NEW_OFFSET
	
		; COPY_FROM_LAST_OFFSET
		call dzx0_elias         ; hl = read_interlaced_elias_gamma(FALSE) 
dzx0_copy:
		xchg                    ; hl = src, de = length
		xthl                    ; ex (sp), hl:
		                        ; tos = src
		                        ; hl = -1
		push h                  ; push -1
		dad b                   ; h = -1 + dst
		mov h, b                ; stay in the buffer!
		xchg                    ; de = dst + offset, hl = length
;		call dzx0_ldir          ; for (i = 0; i < length; i++) write_byte(dst[-offset+i]) 
		push psw
dzx0_ldir_from_buf:
		ldax d
		stax b
		inr e
		inr c                   ; stay within circular buffer
		
		; yield every 16 bytes
		mvi a, 15
		ana c
		cz dzx0_yield 
		dcx h
		mov a,h
		ora l
		jnz dzx0_ldir_from_buf
		mvi h,0
		pop psw
		add a
		                        ; de = de + length
		                        ; hl = 0
		                        ; a, carry = a + a 
		xchg                    ; de = 0, hl = de + length .. discard dst
		pop h                   ; hl = old offset
		xthl                    ; offset = hl, hl = src
		xchg                    ; de = src, hl = 0?
		jnc dzx0_literals       ; if (!read_bit()) goto COPY_LITERALS
		
		; COPY_FROM_NEW_OFFSET
		; Copy from new offset (repeat N bytes from new offset)
dzx0_new_offset:
		call dzx0_elias         ; hl = read_interlaced_elias_gamma()
		mov h,a                 ; h = a
		pop psw                 ; drop offset from stack
		xra a                   ; a = 0
		sub l                   ; l == 0?
		;rz                      ; return
		jz dzx0_ded
		push h                  ; offset = new offset
		; last_offset = last_offset*128-(read_byte()>>1);
		rar\ mov h,a            ; h = hi(last_offset*128)
		ldax d                  ; read_byte()
		rar\ mov l,a            ; l = read_byte()>>1
		inx d                   ; src++
		xthl                    ; offset = hl, hl = old offset
		
		mov a,h                 ; 
		lxi h,1                 ; 
		cnc dzx0_elias_backtrack; 
		inx h
		jmp dzx0_copy
dzx0_elias:
		inr l
dzx0_elias_loop:	
		add a
		jnz dzx0_elias_skip
		ldax d
		inx d
		ral
dzx0_elias_skip:
		rc
dzx0_elias_backtrack:
		dad h
		add a
		jnc dzx0_elias_loop
		jmp dzx0_elias
dzx0_ldir:
		push psw
		mov a, b
		cmp d
		jz dzx0_ldir_from_buf

                ; reached the end of stream
dzx0_ded       
                ; notify gigachad that this stream has finished
                lxi h, dzx0_finish_ctr
                inr m
                ; idle forever: gigachad will restart the task/stream
                call dzx0_yield
                jmp $-3

;
; runtime data (careful with relative equ directives)
;

; task stacks

stacks          
stack_00        equ stacks
stack_01        equ stack_00 + task_stack_size
stack_02        equ stack_01 + task_stack_size
stack_03        equ stack_02 + task_stack_size
stack_04        equ stack_03 + task_stack_size
stack_05        equ stack_04 + task_stack_size
stack_06        equ stack_05 + task_stack_size
stack_07        equ stack_06 + task_stack_size
stack_08        equ stack_07 + task_stack_size
stack_09        equ stack_08 + task_stack_size
stack_10        equ stack_09 + task_stack_size
stack_11        equ stack_10 + task_stack_size
stack_12        equ stack_11 + task_stack_size
stack_13        equ stack_12 + task_stack_size
stack_14        equ stack_13 + task_stack_size
stack_15        equ stack_14 + task_stack_size
stacks_end      equ stack_15 + task_stack_size

; array of task sp: context[i] = task's stack pointer
context         equ stacks_end
context_end     equ context + 2 * n_tasks

context_ptr:    equ context_end
bss_end         equ context_ptr + 2


; buffers for unpacking the streams, must be aligned to 256 byte boundary

buffer00        equ     0xff00 & bss_end + 256        
buffer01        equ     0xff00 & bss_end + 256 * 2        
buffer02        equ     0xff00 & bss_end + 256 * 3
buffer03        equ     0xff00 & bss_end + 256 * 4        
buffer04        equ     0xff00 & bss_end + 256 * 5
buffer05        equ     0xff00 & bss_end + 256 * 6        
buffer06        equ     0xff00 & bss_end + 256 * 7
buffer07        equ     0xff00 & bss_end + 256 * 8        
buffer08        equ     0xff00 & bss_end + 256 * 9
buffer09        equ     0xff00 & bss_end + 256 * 10        
buffer10        equ     0xff00 & bss_end + 256 * 11
buffer11        equ     0xff00 & bss_end + 256 * 12       
buffer12        equ     0xff00 & bss_end + 256 * 13
buffer13        equ     0xff00 & bss_end + 256 * 14       

gigachad_end    equ     0xff00 & bss_end + 256 * 15

	.end
