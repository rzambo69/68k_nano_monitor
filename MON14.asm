; vim:noet:sw=8:ts=8:sts=8:ai:syn=asm68k
;**************************************************************************
;* M68000 Monitor vers. 1.4      (renzo@iol.it)    -    09 Nov 2025
;* 
;*
;* Commands:
;*   x - Examine memory location
;*   d - Dump memory zone
;*   r - Display CPU registers
;*   g - Go (execute) at specified address
;*   e - Execute subroutine at specified  address
;*   f - Fill memory zone with byte value
;*   c - Copy memory zone
;*   i - Insert/modify memory values
;*   q - Exit monitor
;*   ? - Help
;**************************************************************************

        include "68000app.inc"

KEYB_BUFF	DS.B	64
CR		EQU 	$0D
LF		EQU	$0A

REG_D0		DS.L	1
REG_D1		DS.L	1
REG_D2		DS.L	1
REG_D3		DS.L	1
REG_D4		DS.L	1
REG_D5		DS.L	1
REG_D6		DS.L	1
REG_D7		DS.L	1
REG_A0		DS.L	1
REG_A1		DS.L	1
REG_A2		DS.L	1
REG_A3		DS.L	1
REG_A4		DS.L	1
REG_A5		DS.L	1
REG_A6		DS.L	1
REG_A7		DS.L	1


START:          lea.l   INIT_MESSAGE,a0
                sys     OutStr

MAIN_LOOP:      bsr	INIT_REGS
		lea.l   PROMPT,a0
		sys	OutStr

		lea.l	KEYB_BUFF,A0
		moveq	#$3F,D0		; max length 63 char
		moveq	#$0A,D1		; stop when newline char is received
		sys	PromptStr

; converte i caratteri inseriti in maiuscolo

		lea.l	KEYB_BUFF,A0
CAPS1:		move.b	(A0),D0
		bsr	TO_UPPER
		move.b	D0,(A0)
		cmp.b	#$00,D0
		beq	CHK_MENU
		add.l	#$01,A0
		bra	CAPS1

CHK_MENU:	move.b	(KEYB_BUFF),d0
		bsr	TO_UPPER
        
        	cmp.b   #'X',d0
        	beq     CMD_EXAMINE      ; Examine memory
        
        	cmp.b   #'D',d0
        	beq     CMD_DUMP         ; Dump memory
        
        	cmp.b   #'R',d0
        	beq     CMD_REGISTERS    ; Display registers
        
        	cmp.b   #'G',d0
        	beq     CMD_GO           ; Execute code

        	cmp.b   #'E',d0
        	beq     CMD_GOSUB        ; Execute subroutine code
        
        	cmp.b   #'F',d0
        	beq    CMD_FILL        ; Fill memory
        
        	cmp.b   #'C',d0
        	beq     CMD_COPY        ; Copy memory
        
        	cmp.b   #'I',d0
        	beq     CMD_INSERT      ; Insert/modify memory

        	cmp.b   #'Q',d0
        	beq     CMD_EXIT      ; Exit monitor

        	cmp.b   #'?',d0
        	beq     CMD_HELP      ; Insert/modify memory
        
        	lea.l     UNKNOWN_CMD,a0
        	sys	OutStr	       ; Unknown command
        	bra     MAIN_LOOP

;**************************************************************************
;* Command: Examine Memory (x)
;* Syntax: x <address>
;* Displays the contents of the specified memory location
;**************************************************************************

CMD_EXAMINE:	bsr	INIT_REGS
		lea.l	CMD_EXAMINE_MSG,a0
		sys	OutStr

		lea.l	KEYB_BUFF,a0
		sys	OutStr

		move.l	#$00,D0
		move.l	#$00,D1
		move.l	#$00,D2
		lea.l	KEYB_BUFF+2,a0
LX1:		move.b	(a0),D2
		add	#$01,A0
		cmp.b	#$00,d2
		beq	LX2
		cmp.b	#$20,d2
		beq	LX2
	        asl.l   #4,D1

	        CMP.B   #'9',D2
	        BLS     LX3               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE
        
LX3:	        SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE:
       		add     D2,D1
    	        bra     LX1

LX2:		move.l	D1,A0
		move.l	A0,D2
		move.b	(A0),D0

		;stampa <indirizzo> <byte>
		move.w	D0,-(sp)
		move.l	D1,-(sp)
		lea.l	x_fmtstr,a0
		sys	OutFmt
		addq	#$06,sp

	        bra     MAIN_LOOP

x_fmtstr:	dc.b	"\n    ",FMT_H32," ",FMT_H8,"\n",0

;**************************************************************************
;* Command: Dump Memory (d)
;* Syntax: d <start> <end>
;* Dumps memory from start to end address, 16 bytes per line
;**************************************************************************
CMD_DUMP:	bsr	INIT_REGS
		lea.l	CMD_DUMP_MSG,a0
		sys	OutStr

		lea.l	KEYB_BUFF,a0
		sys	OutStr

		lea.l	DUMP_HEAD,a0
		sys	OutStr

		move.l	#$00,D0
		move.l	#$00,D1
		move.l	#$00,D2

		lea.l	KEYB_BUFF+2,a0
LD1:		move.b	(a0),D2
		add	#$01,A0
		cmp.b	#$20,d2
		beq	LD2
	        asl.l   #4,D1

	        CMP.B   #'9',D2
	        BLS     LD3               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_D
        
LD3:	        SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_D:
       		add     D2,D1
    	        bra     LD1

LD2:		move.l	D1,A5		; salva indirizzo inizio dump in A5

; legge indirizzo fine
		move.l	#$00,D0
		move.l	#$00,D1
		move.l	#$00,D2

		move.l	a0,a2
LD4:		move.b	(a2),D2
		add	#$01,A2
		cmp.b	#$00,d2
		beq	LD5
		cmp.b	#$20,d2
		beq	LD5
	        asl.l   #4,D1

	        CMP.B   #'9',D2
	        BLS     LD6               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_D2
        
LD6:	        SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_D2:
       		add     D2,D1
    	        bra     LD4

LD5:		move.l	D1,A6	; salva indirizzo fine dump in A6
		move.l	D1,D4	; e in D4

;stampa da inizio a fine il dump su righe di 16 byte

D_START:	move.l	A5,d0
		move.l	#$00,d3		; i=0

		move.l	D0,-(sp)	;print address
		lea.l	ad_fmtstr,a0
		sys	OutFmt
		addq	#$04,sp

D_PR_BYTE	move.b	(A5),d0		;print byte
		move.w	d0,-(sp)
		lea.l	da_fmtstr,a0
		sys	OutFmt
		addq	#2,sp

		addq	#$01,d3		; i=i+1

		move.l	A5,D5
		cmp.l	D4,D5		; address > end_address?
		bge	D_END		;if yes go to end of dump routine
		addq	#$01,A5		; address = address + 1

		cmp	#$10,d3		; i=16?
		bne	D_PR_BYTE	; if false print next byte
		bra	D_START

D_END		lea.l	ACAPO,a0	; print new line char and return to main prompt
		sys	OutStr
	        bra     MAIN_LOOP

DUMP_HEAD:	dc.b	"\n         00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F",0
ad_fmtstr:	dc.b	"\n",FMT_H32,0
da_fmtstr:	dc.b	" ",FMT_H8,0


;**************************************************************************
;* Command: Display Registers (r)
;* Displays the contents of all CPU registers
;**************************************************************************
CMD_REGISTERS:	;salva PC
		;salva Status Register

;		move.l	D0,REG_D0
;		move.l	D1,REG_D1
;		move.l	D2,REG_D2
;		move.l	D3,REG_D3
;		move.l	D4,REG_D4
;		move.l	D5,REG_D5
;		move.l	D6,REG_D6
;		move.l	D7,REG_D7
;		move.l	A0,REG_A0
;		move.l	A1,REG_A1
;		move.l	A2,REG_A2
;		move.l	A3,REG_A3
;		move.l	A4,REG_A4
;		move.l	A5,REG_A5
;		move.l	A6,REG_A6
;		move.l	A7,REG_A7

		lea.l	CMD_REGISTERS_MSG,a0
		sys	OutStr

; stampa a video i registri

	        bra     MAIN_LOOP

;**************************************************************************
;* Command: Go (g)
;* Syntax: g <address>
;* Begins execution at the specified address
;**************************************************************************
CMD_GO:		bsr	INIT_REGS
		lea.l	CMD_GO_MSG,a0
		sys	OutStr

		move.l	#$00,D0
	    	move.l	#$00,D1
	        move.l	#$00,D2

    		lea.l	KEYB_BUFF+2,a0

LG1:		move.b	(a0),D2
		add     #$01,A0
	    	cmp.b	#$20,d2
	    	beq     LG2
	    	cmp.b	#$00,d2
	    	beq     LG2
	        asl.l   #4,D1

	        CMP.B   #'9',D2
	        BLS     LG3               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_G
        
LG3:	        SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_G:
       		add     D2,D1
	        bra     LG1

LG2:		move.l	D1,A1		; salva indirizzo inizio dump in A1

; esegue codice a partire da indirizzo contenuto in A1

	        jmp     (A1)

;**************************************************************************
;* Command: GoSub (e)
;* Syntax: e <address>
;* Execute subroutine at the specified address
;**************************************************************************
CMD_GOSUB:	bsr	INIT_REGS
		lea.l	CMD_GOSUB_MSG,a0
		sys	OutStr

		move.l	#$00,D0
	    	move.l	#$00,D1
	        move.l	#$00,D2

    		lea.l	KEYB_BUFF+2,a0

LE1:		move.b	(a0),D2
		add     #$01,A0
	    	cmp.b	#$20,d2
	    	beq     LE2
	    	cmp.b	#$00,d2
	    	beq     LE2
	        asl.l   #4,D1

	        CMP.B   #'9',D2
	        BLS     LE3               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_E
        
LE3:	        SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_E:
       		add     D2,D1
	        bra     LE1

LE2:		move.l	D1,A1		; salva indirizzo inizio dump in A1

; esegue la subroutine a partire da indirizzo contenuto in A1 e torna al monitor
; quando incontra l'istruzione RTS

	        jsr     (A1)

	        bra     MAIN_LOOP

;**************************************************************************
;* Command: Fill Memory (f)
;* Syntax: f <start_address> <end_address> <byte>
;* Fills memory from start to end with specified byte value
;**************************************************************************
CMD_FILL:	bsr	INIT_REGS
		lea.l	CMD_FILL_MSG,a0
		sys	OutStr

		move.l	#$00,D0
	    	move.l	#$00,D1
	        move.l	#$00,D2

    		lea.l	KEYB_BUFF+2,a0

LF1:		move.b	(a0),D2
		add     #$01,A0
	    	cmp.b	#$20,d2
	    	beq     LF2
	        asl.l   #4,D1

	        CMP.B   #'9',D2
	        BLS     LF3               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_F
        
LF3:	        SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_F:
       		add     D2,D1
	        bra     LF1

LF2:		move.l	D1,A1		; salva indirizzo inizio dump in A1

; legge indirizzo fine
	    	move.l	#$00,D0
    		move.l	#$00,D1
    		move.l	#$00,D2

    		move.l	a0,a2
;    		add     #$01,a2
LF4:		move.b	(a2),D2
    		add     #$01,A2
    		cmp.b	#$20,d2
    		beq     LF5
	        asl.l   #4,D1
	        CMP.B   #'9',D2
	        BLS     LF6               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_F2
        
LF6:            SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_F2:
       		add     D2,D1
                bra     LF4

LF5:		move.l  A2,A0
                move.l	D1,A2	; salva indirizzo fine dump in A2

; legge byte
	    	move.l	#$00,D0
    		move.l	#$00,D1
    		move.l	#$00,D2

    		move.l	a0,a3
;    		add     #$01,a3
LFF4:		move.b	(a3),D2
    		add     #$01,A3
    		cmp.b	#$00,d2
    		beq     LFF5
    		cmp.b	#$20,d2
    		beq     LFF5
	        asl.l   #4,D1
	        CMP.B   #'9',D2
	        BLS     LFF6               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_F3
        
LFF6:           SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_F3:
       		add     D2,D1
                bra     LFF4

LFF5:		move.l	D1,D4	; salva fill byte in D4

;inizio memory fill

F_START:	move.b	D4,(A1)
                cmp.l   A1,A2
                beq     F_END
                add     #$01,A1
	        bra     F_START

F_END		bra     MAIN_LOOP

;**************************************************************************
;* Command: Copy Memory (c)
;* Syntax: c <from_addr_start> <from_addr_end> <to_addr_start>
;* Copies memory from source to destination for specified length
;**************************************************************************
CMD_COPY:	bsr	INIT_REGS
		lea.l	CMD_COPY_MSG,a0
		sys	OutStr

		move.l	#$00,D0
	    	move.l	#$00,D1
        	move.l	#$00,D2

    		lea.l	KEYB_BUFF+2,a0

LC1:		move.b	(a0),D2
		add	#$01,A0
	    	cmp.b	#$20,d2
	    	beq	LC2
	        asl.l   #4,D1

	        CMP.B   #'9',D2
	        BLS     LC3               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_C
        
LC3:		SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_C:
       		add     D2,D1
	 	bra     LC1

LC2:		move.l	D1,A1		; salva indirizzo inizio dump in A1

; legge indirizzo fine
	    	move.l	#$00,D0
    		move.l	#$00,D1
    		move.l	#$00,D2

    		move.l	a0,a2
;    		add	#$01,a2
LC4:		move.b	(a2),D2
    		add	#$01,A2
    		cmp.b	#$20,d2
    		beq	LC5
	        asl.l   #4,D1
	        CMP.B   #'9',D2
	        BLS     LC6               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_C2
        
LC6:    	SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_C2:
       		add     D2,D1
	 	bra     LC4

LC5:		move.l  A2,A0
	        move.l	D1,A2	; salva indirizzo fine dump in A2

; legge indirizzo inizio area copia
	    	move.l	#$00,D0
    		move.l	#$00,D1
    		move.l	#$00,D2

    		move.l	a0,a3
;    		add	#$01,a3
LCC4:		move.b	(a3),D2
    		add	#$01,A3
    		cmp.b	#$00,d2
    		beq	LCC5
    		cmp.b	#$20,d2
    		beq	LCC5
	        asl.l   #4,D1
	        CMP.B   #'9',D2
	        BLS     LCC6               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_C3
        
LCC6:   	SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_C3:
       		add     D2,D1
		bra     LCC4

LCC5:		move.l	D1,A3	; salva copy byte in A3

;inizio memory fill

C_START:	move.b	(A1),(A3)
            	cmp.l   A1,A2
         	beq     C_END
		add     #$01,A1
      	        add     #$01,A3
	        bra     C_START

C_END		bra     MAIN_LOOP

;**************************************************************************
;* Command: Insert/Modify Memory (i)
;* Syntax: i <address> <value1> [value2 ... value16]
;* Modifies memory starting at address with specified values
;**************************************************************************
CMD_INSERT:	bsr	INIT_REGS
		lea.l	CMD_INSERT_MSG,a0
		sys	OutStr

		move.l	#$00,D0
	    	move.l	#$00,D1
    	        move.l	#$00,D2

    		lea.l	KEYB_BUFF+2,a0

LI1:		move.b	(a0),D2
		add	#$01,A0
	    	cmp.b	#$20,d2
	    	beq	LI2
	        asl.l   #4,D1

	        CMP.B   #'9',D2
	        BLS     LI3               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_I
        
LI3:	    	SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_I:
       		add     D2,D1
    	    	bra     LI1

LI2:		move.l	D1,A1		; salva indirizzo inizio dump in A1

; legge byte
    		move.l	a0,a2
            	move.l  #$00,D3
I_START:   	move.l	#$00,D0
    		move.l	#$00,D1
    		move.l	#$00,D2

LI4:		move.b	(a2),D2
    		add	#$01,A2
    		cmp.b	#$20,d2
    		beq	LI5
    		cmp.b	#$00,d2
    		beq	I_END
	        asl.l   #4,D1
	        CMP.B   #'9',D2
	        BLS     LI6               ; 0-9
	        SUB.B   #'A'-10,D2       ; Convert A-F to 10-15
	        BRA     COMBINE_I2
        
LI6:        	SUB.B   #$30,D2          ; Convert 0-9 to 0-9
        
COMBINE_I2:
       		add     D2,D1

    	    	bra     LI4

LI5:		addq    #$01,d3
            	cmp.l   #$0F,d3
            	bgt     I_ERROR
            	move.l  D1,D4   ; salva byte in D4

;stampa da inizio a fine il dump su righe di 16 byte

		move.b	d4,(a1)
            	add     #$01,a1
            	bra     I_START

I_END		move.b  d1,(a1)
		bra	MAIN_LOOP

I_ERROR     	lea.l	I_ERR_MSG,a0
		sys	OutStr
		bra	MAIN_LOOP

I_ERR_MSG	dc.b    '\nInsert error: too many arguments\nOnly 16 bytes are saved!\n',0


;**************************************************************************
;* Command: Exit monitor (q)
;* Syntax: q
;* Exit monitor application and returns to the system
;**************************************************************************
CMD_EXIT:	lea.l	CMD_EXIT_MSG,a0
		sys	OutStr
	        sys     Exit


;**************************************************************************
;* Command: Help (?)
;* Syntax: ?
;* Print help
;**************************************************************************
CMD_HELP:	bsr	INIT_REGS
		lea.l	CMD_HELP_MSG,a0
		sys	OutStr
	        bra     MAIN_LOOP



;**************************************************
; Convert character in D0 to uppercase
;**************************************************
TO_UPPER:
        CMP.B   #'a',D0
        BLO     TO_UPPER_DONE
        CMP.B   #'z',D0
        BHI     TO_UPPER_DONE
        SUB.B   #$20,D0         ; Convert to uppercase
        
TO_UPPER_DONE:
        RTS

;*************************************************
; Initialize all cpu registers
;*************************************************
INIT_REGS:
	move.l #$00,A0
	move.l #$00,A1
	move.l #$00,A2
	move.l #$00,A3
	move.l #$00,A4
	move.l #$00,A5
	move.l #$00,A6

	move.l #$00,D0
	move.l #$00,D1
	move.l #$00,D2
	move.l #$00,D3
	move.l #$00,D4
	move.l #$00,D5
	move.l #$00,D6
	move.l #$00,D7

	RTS


;**************************************************************************
;* Data Section
;**************************************************************************
INIT_MESSAGE:
        DC.B    "M68000 Monitor v1.4    (renzo@iol.it)  -  09 Nov 2025\n"
	DC.B	"Commands: x,d,(r),g,e,f,c,i,q\n"
	DC.B	"  press ? for help\n",0

PROMPT:
        DC.B    "\n> ",0

UNKNOWN_CMD:
        DC.B    "\nUnknown command\n",0

REGS_MESSAGE:
        DC.B    "Registers:\n",0

GO_MESSAGE:
        DC.B    "Executing at address ",0

GOSUB_MESSAGE:
        DC.B    "Executing subroutine at address ",0

FILL_DONE_MSG:
        DC.B    "Memory filled\n",0

COPY_DONE_MSG:
        DC.B    "Memory copied\n",0

INSERT_DONE_MSG:
        DC.B    "Memory modified\n",0

CMD_EXAMINE_MSG:
	dc.b	"\nx=examine command\n",0

CMD_DUMP_MSG:
	dc.b	"\nd=dump command\n",0

CMD_REGISTERS_MSG:
	dc.b	"\nr=register command\n",0

CMD_GO_MSG:
	dc.b	"\ng=execute command\n",0

CMD_GOSUB_MSG:
	dc.b	"\ne=execute subroutine command\n",0

CMD_FILL_MSG:
	dc.b	"\nf=fill command\n",0

CMD_COPY_MSG:
	dc.b	"\nc=copy command\n",0

CMD_INSERT_MSG:
	dc.b	"\ni=insert command\n",0

CMD_EXIT_MSG:
	dc.b	"\n\n Exit Monitor\n             Bye!\n\n",0

CMD_HELP_MSG:
	dc.b	"\n\nCommands:\n"
	dc.b	"x <address>					Displays the contents of the specified memory <address>\n"
	dc.b	"d <start> <end>					Dumps memory from <start> to <end> address, 16 bytes per line\n"
	dc.b	"r						Displays the contents of all CPU registers\n"
	dc.b	"g <address>					Begins execution at the specified <address>\n"
        dc.b	"e <address>					Execute subroutine at the specified <address> and return to monitor\n"
	dc.b	"f <start> <end> <byte>				Fills memory from <start> address to <end> address with specified <byte> value\n"
	dc.b	"c <from_addr_start> <from_addr_end> <to_addr_start>	Copies memory from source to destination for specified length\n"
	dc.b	"i <address> <value1> [value2 ... value16]	Modifies memory starting at address with specified values\n"
	dc.b	"q						Exit Monitor and returns to the system\n"
	dc.b	"?						Print this command list\n\n"
	dc.b	"where <address> is hex number from 000000 to FFFFFF; <byte> is hex number from 00 to FF\n\n\n",0

SPACE:	dc.b	" ",0
ACAPO:	dc.b	"\n",0



;**************************************************************************
;* End of Monitor Program
;**************************************************************************