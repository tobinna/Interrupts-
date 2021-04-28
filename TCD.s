; Interrupt Handling Sample
; (c) Mike Brady, 2021.

	area	tcd,code,readonly
	export	__main
__main

; Definitions  -- references to 'UM' are to the User Manual.

; Timer Stuff -- UM, Table 173

T0	equ	0xE0004000		; Timer 0 Base Address
T1	equ	0xE0008000


IR	equ	0			; Add this to a timer's base address to get actual register address
TCR	equ	4
MCR	equ	0x14
MR0	equ	0x18

TimerCommandReset	equ	2
TimerCommandRun	equ	1
TimerModeResetAndInterrupt	equ	3
TimerResetTimer0Interrupt	equ	1
TimerResetAllInterrupts	equ	0xFF

; VIC Stuff -- UM, Table 41
VIC	equ	0xFFFFF000		; VIC Base Address
IntEnable	equ	0x10
VectAddr	equ	0x30
VectAddr0	equ	0x100
VectCtrl0	equ	0x200

Timer0ChannelNumber	equ	4	; UM, Table 63
Timer0Mask	equ	1<<Timer0ChannelNumber	; UM, Table 63
IRQslot_en	equ	5		; UM, Table 58

; initialisation code
	mov r0, #0
	ldr r1, =counter
	str r0, [r1]
; Initialise the VIC
	ldr	r0,=VIC			; looking at you, VIC!

	ldr	r1,=irqhan
	str	r1,[r0,#VectAddr0] 	; associate our interrupt handler with Vectored Interrupt 0

	mov	r1,#Timer0ChannelNumber+(1<<IRQslot_en)
	str	r1,[r0,#VectCtrl0] 	; make Timer 0 interrupts the source of Vectored Interrupt 0

	mov	r1,#Timer0Mask
	str	r1,[r0,#IntEnable]	; enable Timer 0 interrupts to be recognised by the VIC

	mov	r1,#0
	str	r1,[r0,#VectAddr]   	; remove any pending interrupt (may not be needed)

; Initialise Timer 0
	ldr	r0,=T0			; looking at you, Timer 0!

	mov	r1,#TimerCommandReset
	str	r1,[r0,#TCR]

	mov	r1,#TimerResetAllInterrupts
	str	r1,[r0,#IR]

	ldr	r1,=(18432000)-1	 ; 1s adds to the output
	str	r1,[r0,#MR0]

	mov	r1,#TimerModeResetAndInterrupt
	str	r1,[r0,#MCR]

	mov	r1,#TimerCommandRun
	str	r1,[r0,#TCR]

IO1DIR	EQU	0xE0028018			; Set up my GPIO variables
IO1PIN	EQU 0xE0028010

	
	ldr	r1,=IO1DIR				; Set up my registers as the GPIO places 
	ldr r0, =0xFFFFFFFF
	str r0, [r1]
	
	ldr r2, =counter			; Set up counter as display and interupt
	ldr	r1,=0x00f00f00	
	str r1, [r2]
		
	ldr r0,=IO1PIN	
	str r1,[r0]
	
wlop 
	
	ldr r1, [r2]				; Load value of counter into r1
	str r1, [r0]				; Display the current count on the GPIO
	ldr r4, =0x0000000f			; Single out the least significant 4 bits
	and r3, r4, r1
	cmp r3, #0x0000000A			; If the least significant four is ten,
	beq ten						; Go to the ten subroutine
	ldr r4, =0x000000f0
	and r3, r4, r1
	cmp r3, #0x00000060			; If the tens column has gotten to 60 seconds,
	beq min						; Go to the minute subroutine
	ldr r4, =0x0000f000
	and r3, r4, r1
	cmp r3, #0x0000A000			; If the minutes column has gotten to tens of minutes,
	beq ten_min					; Go to the tens of minutes subroutine
	ldr r4, =0x000f0000
	and r3, r4, r1
	cmp r3, #0x00060000			; If the tens of minutes column has gotten to 60 minutes,
	beq hour					; Go to the hours subroutine 
	ldr r4, =0x0f000000
	and r3, r4, r1
	cmp r3, #0x0A000000			; If the hours column has gotten to tens of hours,
	beq hour_tens				; Go to the tens of hours subroutine
	ldr r4, =0xff000000
	and r3, r4, r1
	cmp r3, #0x24000000			; If the hours of the day is currently 24,
	beq day						; Start a new day!!!!!!
	
	b wlop

ten
	ldr r2, =counter			
	sub r1, r1, #10				; Takeaway the digits in the LS block
	add r1, r1, #16				; Add a digit to the tens block
	str r1, [r2]				; Store the result back as the counter
	b wlop
	
min
	ldr r2, =counter			
	sub r1, r1, #96				; Takeaway the digits in the tens of seconds block
	add r1, r1, #4096			; Add a digit to the minutes block
	str r1, [r2]				; Store the result back as the counter
	b wlop
	
ten_min
	ldr r2, =counter
	sub r1, r1, #40960			; Takeaway the digits in the minutes block
	add r1, r1, #65536			; Add a digit to the tens of minutes block
	str r1, [r2]				; Store the result back as the counter
	b wlop

hour
	ldr r2, =counter
	sub r1, r1, #393216			; Takeaway the digits in the tens of minutes block
	add r1, r1, #16777216		; Add a digit to the hours block
	str r1, [r2]				; Store the result back as the counter
	b wlop

hour_tens
	ldr r2, =counter
	sub r1, r1, #167772160		; Takeaway the digits in the hours block
	add r1, r1, #268435456		; Add a digit to the tens of hours block
	str r1, [r2]				; Store the result back as the counter
	b wlop

day
	ldr r2, =counter
	ldr r4, =0x00f00f00			; Clear all the values in the clock	
	and r3, r4, r1
	str r3, [r2]				; Store the result back as the counter
	b wlop
	
fin b fin







	AREA	InterruptStuff, CODE, READONLY
irqhan	sub	lr,lr,#4
	stmfd	sp!,{r0-r1,lr}	; the lr will be restored to the pc

;this is the body of the interrupt handler

;here you'd put the unique part of your interrupt handler
;all the other stuff is "housekeeping" to save registers and acknowledge interrupts

;this is where we stop the timer from making the interrupt request to the VIC
;i.e. we 'acknowledge' the interrupt
	ldr	r0,=T0
	mov	r1,#TimerResetTimer0Interrupt
	str	r1,[r0,#IR]	   	; remove MR0 interrupt request from timer

;here we stop the VIC from making the interrupt request to the CPU:
	ldr	r0,=VIC
	mov	r1,#0
	str	r1,[r0,#VectAddr]	; reset VIC
	
	ldr r0, =counter
	ldr r1, [r0]
	add r1, #1 ;CHANGED
	str r1, [r0]

	ldmfd	sp!,{r0-r1,pc}^	; return from interrupt, restoring pc from lr
				; and also restoring the CPSR
	AREA	InterruptData, DATA, READWRITE
counter space 4			; counter

                END
