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

	cseg
	mov		wdtcn,#0DEh
	mov		wdtcn,#0ADh

	mov			xbr2,#40H		; activate I/O ports
;---------------------------------------------
	jmp main		; jump to main to avoid writing into interrupts

;--------------------------------------------------------------------
;Serial interrupt
		
;	DESCRIPTION
;	When serial interupt flag is set for either transmit or receive
;	PC will jump to this location 
;--------------------------------------------------------------------
int_serial:
	org 0020H		; location where timer interrupt will jump to


int_t2:
	org 002BH		; location where timer interrupt will jump to
	jmp t2_isr	; jump to interrupt service routine for timer 2


main:
	; fosc = 22.1184 MHz. => fosc/12 * 10ms = 18432. This is the value
	; used for timer 2 to obtain an overflow every 10ms
	mov 	RCAP2H,#HIGH(-18432)	; set high bits for timer
	mov 	RCAP2L,#LOW(-18432)		; set low bits for timer
	mov		TH2,#HIGH(-18432)			; set high bits for auto reload
	mov		TL2,#LOW(-18432)			; set low bits for auto reload
	setb	TR2										; start the timer
	mov 	IE,#0B0h							; enable interrupts, enable timer 2 and serial interrupts

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
;--------------------------------------------------------------------
t2_isr:

	END		; end of the program