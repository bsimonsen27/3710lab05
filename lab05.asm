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
	ms_counter:	ds 1		; counter to check 
	

	cseg
	mov		wdtcn,#0DEh
	mov		wdtcn,#0ADh

	mov			xbr2,#40H		; activate I/O ports
;---------------------------------------------
	jmp main		; jump to main to avoid writing into interrupts

int_serial:
	org 0020H				; location where timer interrupt will jump to
	jmp serial_isr	; jump to serial interrupt service routine

int_t2:
	org 002BH		; location where timer interrupt will jump to
	jmp t2_isr	; jump to interrupt service routine for timer 2


;--------------------------------------------------------------------
;main
		
;	DESCRIPTION
;	PC will jump to this subroutine and will only run once then proceed
; down into loop1. Should only run these lines of code 1 time upon
; starting up.
;--------------------------------------------------------------------
main:
	

; fosc = 22.1184 MHz. => fosc/12 * 10ms = 18432. This is the value
	; used for timer 2 to obtain an overflow every 10ms
	mov 	RCAP2H,#HIGH(-18432)	; set high bits for timer
	mov 	RCAP2L,#LOW(-18432)		; set low bits for timer
	mov		TH2,#HIGH(-18432)			; set high bits for auto reload
	mov		TL2,#LOW(-18432)			; set low bits for auto reload
	setb	TR2										; start the timer
	mov 	IE,#0B0h							; enable interrupts, enable timer 2 and serial interrupt
	mov		R1,#10								; initialize R1 to 10 for converting 100Hz to 10Hz
	mov		running,#0						; initialize running state to off
	mov ms_counter, #0					; initialize the milisecond delay to 0
;--------------------------------------------------------------------
;loop1
		
;	DESCRIPTION
;	Wait in this loop for the interrupts.
;--------------------------------------------------------------------
loop1:
	jmp loop1
	

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
			; if 1 we are running

;--------------------------------------------------------------------
;stop_state
		
;	DESCRIPTION
;	This subroutine will handle responses to the buttons when the timer
; is stopped. 
;
;--------------------------------------------------------------------
stop_state:
	call	chk_btn						; get the values of the buttons, stored in ACC
	; left button on ACC.6	|		right button on ACC.7
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
	mov		decimal,#0		; reset decimal number value to 0

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
	;??????????????????????? do we want to inc counter before a reset? probably not
	djnz ms_counter, no_inc		; check if it's time to increment
	mov ms_counter, #9
	reti						; return from the interrupt

no_inc:
	

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
	mov 	running,#0	; send to stop state

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
	jb		RI,receive_state
	jb		TI,transmit_state

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
	clr 	RI								; clear receive interrupt flag
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
	mov		running,#0				; mov to stop state
	reti		; return from interrupt

c_low_compare:
	cjne	A,#63h,T_compare	; 63h represent 'c' for run
	mov		numbr,#0					; clear the number
	mov		running,#0				; mov to stop state
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

;--------------------------------------------------------------------
;transmit_state
		
;	DESCRIPTION
;	Jump to this state when we have received a character on the serial
;	port
;
;--------------------------------------------------------------------
transmit_state:
	clr TI	; clear transmit interrupt flag

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