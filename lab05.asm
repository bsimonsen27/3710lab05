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
	old_btn: 	ds 1		; old buttons
	numbr:		ds 1		; whole number value 0-9
	decimal:	ds 1		; decimal value 0-9
	running:	ds 1		; 1 if clock is running, 0 if stopped

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
	mov		A,running
	cjne	A,#0,run_state		; if 1 we are running
stop_state:
	call	chk_btn						; get the values of the buttons, stored in ACC
	; left button on ACC.6	|		right button on ACC.7

	reti						; return from the interrupt


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
	jb ACC.4,run_reset			; if right btn pressed, reset the clk to 0
	reti						; return from the interrupt

run_reset:
; reset the numbers back to 0
	mov		numbr,#0		; reset number value to 0
	mov		decimal,#0	; reset decimal value to 0
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

	reti		; return from interrupt

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