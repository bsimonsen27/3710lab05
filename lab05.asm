;==========================================================
; Program Name: lab05.asm
;
;	Authors: Paul Runov & Brendon Simonsen
;
; Description:
; This program will simulate a stopwatch to be used on the
; boards provided in ECE3710 class. One button will act as 
; a start/stop button while the other will act a reset.
; When stopped, a number between 0.0 and 9.9 will be displayed
; on the LED bar as an 8-bit number. There is also serial
; communication which will enable commands to be received as 
; well as the time transmitted
;
; Company:
;	Weber State University 
;
; Date			Version		Description
; ----			-------		-----------
; 3/9/2024	V1.0			Initial description
;==========================================================

$include (c8051f020.inc)

	; declaring variables
	dseg at 30h
	old_btn: 		ds 1		; old buttons
	numbr:			ds 1		; whole number value 0-9
	decimal:		ds 1		; decimal value 0-9
	running:		ds 1		; 1 if clock is running, 0 if stopped
	ms_counter:	ds 1		; counter to check for 10 millisecond delay
	trans_cnt:  ds 1		; counter to keep track of what to send
	


	cseg
	jmp setup

int_serial:
	org 0023H				; location where timer interrupt will jump to
	jmp serial_isr	; jump to serial interrupt service routine

int_t2:
	org 002BH		; location where timer interrupt will jump to
	jmp t2_isr	; jump to interrupt service routine for timer 2


;--------------------------------------------------------------------
;SETUP
		
;	DESCRIPTION
;	PC will jump to this subroutine and will only run once then proceed
; down into loop1. Should only run these lines of code 1 time upon
; starting up.
;--------------------------------------------------------------------
setup:
	mov wdtcn,#0DEh 	; disable watchdog
	mov wdtcn,#0ADh
	mov xbr2,#40h	    ; enable port output
	mov xbr0,#04h	    ; enable uart 0
	;setb P2.7                   ; Input button (right)
	mov oscxcn,#67H	  ; turn on external crystal
	mov tmod,#20H	    ; wait 1ms using T1 mode 2
	mov th1,#256-167	; 2MHz clock, 167 counts = 1ms
	setb tr1

	wait1:
		jnb tf1,wait1
		clr tr1		    	; 1ms has elapsed, stop timer
		clr tf1
	wait2:
		mov a,oscxcn		; now wait for crystal to stabilize
		jnb acc.7, wait2
		mov oscicn,#8		; engage! Now using 22.1184MHz
		mov scon0,#50H	; 8-bit, variable baud, receive enable
		mov th1,#-6	    ; 9600 baud
		setb tr1	   		; start baud clock
		
	
;---------------------------------------------

	
; fosc = 22.1184 MHz. => fosc/12 * 10ms = 18432. This is the value
	; used for timer 2 to obtain an overflow every 10ms
	mov 	RCAP2H,#HIGH(-18432)	; set high bits for timer
	mov 	RCAP2L,#LOW(-18432)		; set low bits for timer
	mov		TH2,#HIGH(-18432)			; set high bits for auto reload
	mov		TL2,#LOW(-18432)			; set low bits for auto reload
	setb	TR2										; start the timer
	mov 	IE,#0B0h							; enable interrupts, enable timer 2 and serial interrupt
	mov		R1,#10								; initialize R1 to 10 for converting 100Hz to 10Hz
	mov		running,#1						; initialize running state to off
	mov 	ms_counter,#9h				; initialize the milisecond delay to 0
	mov 	trans_cnt,#0h
;--------------------------------------------------------------------
;Main
;	DESCRIPTION
;	Wait in this loop for the interrupts.
;--------------------------------------------------------------------
main: 
	jmp main
	

;--------------------------------------------------------------------
;timer 2 interrupt service routine
		
;	DESCRIPTION
;	When the timer 2 interrupt flag is set, program counter will come here
; to perfom logic.
;
;	OUTPUT
;	R1: store counter to manage 10Hz rate
;	R2: store value of whole number value
;	R3: store value of decimal numter
;
;--------------------------------------------------------------------
t2_isr:
; first check if we are running 
	clr 	TF2		; clear timer 2 interrupt flag
	mov		A,running
	cjne	A,#0,run_state

;--------------------------------------------------------------------
;stop_state
		
;	DESCRIPTION
;	This subroutine will handle responses to the buttons when the timer
; is stopped. 
;
;--------------------------------------------------------------------
stop_state:
	call	chk_btn						; get the values of the buttons, stored in ACC
	jb		ACC.6,stop_to_start		; left button pressed to start the timer
	jb		ACC.7,stop_reset			; right button pressed to reset the clock

	reti						; return from the interrupt


;--------------------------------------------------------------------
;stop_to_start
		
;	DESCRIPTION
;	When left button is pressed to start the clock 
;
;--------------------------------------------------------------------
stop_to_start:
	mov		running,#1		; 1 to indicate in running state

	reti								; return from interrupt

;--------------------------------------------------------------------
;stop_reset
		
;	DESCRIPTION
;	Right button pressed while clock is stopped to reset the clock 
;
;--------------------------------------------------------------------
stop_reset:
	mov		numbr,#0			; reset whole number value to 0
	;mov		decimal,#0		; reset decimal number value to 0
	call 	disp_led			; display the new number, 0

	reti

;--------------------------------------------------------------------
;run_state
		
;	DESCRIPTION
;	This subroutine will handle responses to the buttons when the timer
; is running. 
;
;--------------------------------------------------------------------
run_state:
	call	chk_btn						; get the values of the buttons, stored in ACC
	; left button on ACC.6 (start/stop)		|		right button on ACC.7 (reset)
	jb ACC.6,start_stop			; if left btn has been pressed, start or stop the clk
	jb ACC.7,run_reset			; if right btn pressed, reset the clk to 0
	djnz ms_counter, no_inc		; check if it's time to increment
	mov ms_counter, #9

; increment our clock time
	;mov 	A,numbr
	;add 	A,#1			; increment the number
	;mov		numbr,A
	;anl		A,#0Fh		; mask lower 4 bits
	;cjne	A,#0Ah,display_return		; check if we have reached decimal 10
	; reached X.9, need to increment whole number and reset decimal
	;mov		A,numbr
	;add		A,#10h		; increment whole number portion
	;anl		A,#0F0h		; reset dcimal portion and copy whole portion
	;mov		numbr,A		; move number back to the stored variable
	;cjne	A,#0A0h,display_return	; check if we have reach 10
	;mov		numbr,#0	; reset the number to 0
	mov A, numbr
	add A, #1
	da 	A
	mov numbr, A
	jmp		display_return

	reti				; return from the interrupt

display_return:
	call disp_led		; function to display on LED
	reti						;return from interrupt

no_inc:
	reti				; return from the interrupt
	

;--------------------------------------------------------------------
;disp_led
		
;	DESCRIPTION
;	Display our decimal number on the LED bar in 8-bit representation
;
;--------------------------------------------------------------------
disp_led:
	; logic 0 will turn on LED
	; first clear the LEDs
	mov 	P3,#0FFh
	setb 	P2.0
	setb 	P2.1
	mov		A,numbr	
	cpl		A				; cpl number value before displaying it
	mov P3,A			; move number into P3 to only display 8-bits
	ret

;--------------------------------------------------------------------
;stop_reset
		
;	DESCRIPTION
;	Right button pressed while clock is stopped to reset the clock 
;
;--------------------------------------------------------------------
run_reset:
; reset the numbers back to 0
	mov		numbr,#0		; reset number value to 0
	mov		decimal,#0	; reset decimal value to 0
	;mov 	running,#0	; send to stop state
	call 	disp_led		; display new number, 0

	reti							; return from the interrupt

;--------------------------------------------------------------------
;start_stop
		
;	DESCRIPTION
;	When the left button is pressed, this subroutine will either start
; or stop the clock and display the time on the LEDs
;
;--------------------------------------------------------------------
start_stop:
	mov		running,#0		; 0 to indicate we are in stoping state

	reti

;--------------------------------------------------------------------
;Serial interrupt
		
;	DESCRIPTION
;	When serial interupt flag is set for either transmit or receive
;	PC will jump to this location 
;
;--------------------------------------------------------------------
serial_isr:
	jbc		RI,receive_state
	jbc		TI,transmit_state

	reti		; return from interrupt

;--------------------------------------------------------------------
;receive_state
		
;	DESCRIPTION
;	Jump to this state when we have received a character on the serial
;	port
;
;--------------------------------------------------------------------
receive_state:
	mov 	A,SBUF0						;	SBUF0 holds value of serial port
	cjne	A,#52h,r_compare	; 52h represent 'R' for run
	mov		running,#1				; mov to running state
	reti		; return from interrupt

r_compare:
	cjne	A,#72h,S_compare	; 72h represent 'r' for run
	mov		running,#1				; mov to running state
	reti		; return from interrupt

S_compare:
	cjne	A,#53h,s_low_compare	; 53h represent 'S' for run
	mov		running,#0				; mov to stop state
	reti		; return from interrupt

s_low_compare:
	cjne	A,#73h,C_compare	; 73h represent 's' for run
	mov		running,#0				; mov to stop state
	reti		; return from interrupt

C_compare:
	cjne	A,#43h,c_low_compare	; 43h represent 'C' for run
	mov		numbr,#0					; clear the number
	;mov		running,#0				; mov to stop state
	call 	disp_led
	reti		; return from interrupt

c_low_compare:
	cjne	A,#63h,T_compare	; 63h represent 'c' for run
	mov		numbr,#0					; clear the number
	;mov		running,#0				; mov to stop state
	call  disp_led
	reti		; return from interrupt

T_compare:
	cjne	A,#54h,t_low_compare	; 54h represent 'T' for run
	jmp		transmit_time
	reti		; return from interrupt

t_low_compare:
	cjne	A,#74h,end_compare	; 74h represent 't' for run
	jmp		transmit_time
	reti		; return from interrupt

end_compare:
	reti		; return from interrupt, no acition taken


;--------------------------------------------------------------------
;transmit_time
		
;	DESCRIPTION
;	Transmit the time of our clock
;
;--------------------------------------------------------------------
transmit_time:
	mov 	R3, numbr			;save the number
	mov 	A, R3					;mov and mask the value
	anl 	A, #11110000b	
	swap  A
	add 	A, #30h				; change to ascii representation
	mov 	SBUF0, A			;send the first value

	inc 	trans_cnt			;increment the count to keep track of what to send
	reti
;--------------------------------------------------------------------
;transmit_state
		
;	DESCRIPTION
;	Jump to this state when we have received a character on the serial
;	port
;
;--------------------------------------------------------------------
transmit_state:
	mov  A, #1
	cjne A, trans_cnt, not_one 		;statement for period
	mov SBUF0, #2Eh

	inc		trans_cnt
	reti
not_one:
	mov  A, #2
	cjne A, trans_cnt, not_two   ;statement for milliseconds
	mov 	A, R3									 ;mov and mask the value
	anl 	A, #0Fh	
	add 	A, #30h								 ; change to ascii representation
	mov 	SBUF0, A	

	inc		trans_cnt
	reti
not_two:	
	mov  A, #3
	cjne A, trans_cnt, not_three	;statement for Carriage Return
	mov	 SBUF0, #0Dh

	inc		trans_cnt
	reti
not_three:											;statement for Line Feed
	mov 	A, #4
	cjne  A, trans_cnt, not_four  ;statement for end
	mov SBUf0, #0Ah

	inc 	trans_cnt
	reti

not_four:
	mov 	trans_cnt, #0h
	reti
	


;-------------------------------------------------------
;CHECK_BUTTON
;
; DESCRIPTION:
; Checks if the buttons have been pressed. Has code to 
; protect against the button being held down. 

;	OUTPUT
;	values of buttons are stored in accumulator
;
;-------------------------------------------------------
chk_btn:	mov A,P2
					cpl A
					xch	A, old_btn
					xrl A, old_btn
					anl A, old_btn

					
					ret

	END		; end of the program