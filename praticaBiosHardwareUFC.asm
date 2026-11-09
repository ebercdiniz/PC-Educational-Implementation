;---------------------------------------------
; Mapa de I/O
;
; 10h  8251 Data
; 12h  8251 Status/Control -> Usa o pino AD1 ao inves do AD0.
; 20h  8255
; 40h  8253 Counter 0
; 42h  8253 Counter 1
; 44h  8253 Counter 2
; 46h  8253 Command
; 80h  8259 Command INTA00
; 82h  8259 Data INTA01
;---------------------------------------------
; Mapa de Memória
; 00000h–003FFh	Interrupt Vector Table (IVT)
; 00400h–004FFh	BIOS Data Area (BDA)
; 00500h em diante RAM Convencional
; E0000h–FFFFFh	128 kB BIOS ROM
;---------------------------------------------


.8086
.model large

.LIST

;------------------------------------------------------------------------
;	PORTAR A BIOS DO XT 5150 DE ABR 1983 PARA O NOSSO HARDWARE	:
;	AS ROTINAS DA BIOS SÃO SOMENTE INTERRUPÇÃO POR SOFTWARE  	:
;	AS MODIFICAÇÕES FEITAS SERÃO PARA ADEQUAR ESSA BIOS AO		:
;	NOSSO HARDWARE. ENDEREÇOS ABSOLUTOS DENTRO DO SEGMENTO		:
;	DE CÓDIGO VIOLAM A ESTRUTURA E O DESIGN DA BIOS SEGUNDO		:
;	A PRÓPRIA IBM							:
;------------------------------------------------------------------------

;----------------------------------------
;		PORTOS			:
;----------------------------------------
;PORT_A		EQU	60H		; 8255 PORT A ADDR SEM UTILIZACAO
;PORT_B		EQU	61H		; 8255 PORT B ADDR SEM UTILIZACAO
;PORT_C		EQU	62H		; 8255 PORT C ADDR SEM UTILIZACAO
;CMD_PORT	EQU	63H		; 8255 COMANDO SEM UTILIZACAO
INTA00		EQU	80H		; 8259 COMANDO
INTA01		EQU	82H		; 8259 DADOS
EOI		EQU	20H
TIMER		EQU	40H
TIM_CTL 	EQU	46H		; 8253 TIMER CONTROLE
TIMER0		EQU	40H		; 8253 CONTADOR 0
TMINT		EQU	01		; TIMER 0 INTR RECVD MASK
DMA08		EQU	08		; DMA STATUS REG PORT ADDR
DMA		EQU	00		; DMA CHANNEL 0 ADDRESS REG PORT ADDR
MAX_PERIOD	EQU	540H
MIN_PERIOD	EQU	410H
;KBD_IN		EQU	60H		; TECLADO DATA IN ADDR PORT
;KBDINT		EQU	02		; TECLADO MASCARA INTR
;KB_DATA 	EQU	60H		; VARREDURA DO TECLADO CODIGO PORTA
;KB_CTL		EQU	61H		; BITS DE CONTROLE PARA TECLADO

;----------------------------------------
;	 LOCALIZAÇÃO DAS INTERRUPÇÕES	:
;----------------------------------------

ABS0	SEGMENT AT 0
STG_LOC0	LABEL	BYTE
	ORG	2*4
NMI_PTR 	LABEL	WORD
	ORG	5*4
INT5_PTR	LABEL	WORD
	ORG	8*4
INT_ADDR	LABEL	WORD
INT_PTR 	LABEL	DWORD
	ORG	10H*4
VIDEO_INT	LABEL	WORD
	ORG	1DH*4
PARM_PTR	LABEL	DWORD		; POINTER TO VIDEO PARMS
	ORG	18H*4
BASIC_PTR	LABEL	WORD		; ENTRY POINT FOR CASSETTE BASIC
	ORG	01EH*4			; INTERRUPT 1EH
DISK_POINTER	LABEL	DWORD
	ORG	01FH*4			; LOCATION OF POINTER
EXT_PTR LABEL	DWORD			; POINTER TO EXTENSION
	ORG	400H
DATA_AREA	LABEL	BYTE		; ABSOLUTE LOCATION OF DATA SEGMENT
DATA_WORD	LABEL	WORD
	ORG	0500H
MFG_TEST_RTN	LABEL	FAR
	ORG	7C00H
BOOT_LOCN	LABEL	FAR
UART_OFFSET  	EQU	0000H
UART_SEGMENT 	EQU	0E000h

ABS0		ENDS

;------------------------------------------------
; STACK -- USED DURING INITIALIZATION ONLY	:
;------------------------------------------------

STACK	SEGMENT AT 30H
	DW	128 DUP(?)
TOS	LABEL	WORD
STACK	ENDS

;----------------------------------------
;	ROM BIOS DATA AREAS		:
;----------------------------------------

DATA	SEGMENT AT 40H
RS232_BASE	DW	4 DUP(?)	; ADDRESSES OF RS232 ADAPTERS
PRINTER_BASE	DW	4 DUP(?)	; ADDRESSES OF PRINTERS
EQUIP_FLAG	DW	?		; INSTALLED HARDWARE
MFG_TST 	DB	?		; INITIALIZATION FLAG
MEMORY_SIZE	DW	?		; MEMORY SIZE IN K BYTES


;O MONTADOR ORIGINAL DA IBM ACEITA QUE DOIS LABELS DE TABELAS
;REALOCAVEIS SEJA SOMADO (DATA_AREA[OFFSET MFG_ERR_FLAG] POR EX), 
;MAS O JWASM NÃO. ENTÃO DEVEMOS MODIFICAR MFG_ERR_FLAG DE DB PARA
;EQU
;MFG_ERR_FLAG	DB	?		; SCRATCHPAD FOR MANUFACTURING
MFG_ERR_FLAG	EQU	15H		; SCRATCHPAD FOR MANUFACTURING

		DB	?		; ERROR CODES

;----------------------------------------
;	KEYBOARD DATA AREAS		:
;----------------------------------------

KB_FLAG 	DB	?

;----- SHIFT FLAG EQUATES WITHIN KB_FLAG

INS_STATE	EQU	80H		; INSERT STATE IS ACTIVE
CAPS_STATE	EQU	40H		; CAPS LOCK STATE HAS BEEN TOGGLED
NUM_STATE	EQU	20H		; NUM LOCK STATE HAS BEEN TOGGLED
SCROLL_STATE	EQU	10H		; SCROLL LOCK STATE HAS BEEN TOGGLED
ALT_SHIFT	EQU	08H		; ALTERNATE SHIFT KEY DEPRESSED
CTL_SHIFT	EQU	04H		; CONTROL SHIFT KEY DEPRESSED
LEFT_SHIFT	EQU	02H		; LEFT SHIFT KEY DEPRESSED
RIGHT_SHIFT	EQU	01H		; RIGHT SHIFT KEY DEPRESSED

KB_FLAG_1	DB	?		; SECOND BYTE OF KEYBOARD STATUS

INS_SHIFT	EQU	80H		; INSERT KEY IS DEPRESSED
CAPS_SHIFT	EQU	40H		; CAPS LOCK KEY IS DEPRESSED
NUM_SHIFT	EQU	20H		; NUM LOCK KEY IS DEPRESSED
SCROLL_SHIFT	EQU	10H		; SCROLL LOCK KEY IS DEPRESSED
HOLD_STATE	EQU	08H		; SUSPEND KEY HAS BEEN TOGGLED

ALT_INPUT	DB	?		; STORAGE FOR ALTERNATE KEYPAD ENTRY
BUFFER_HEAD	DW	?		; POINTER TO HEAD OF KEYBOARD BUFFER
BUFFER_TAIL	DW	?		; POINTER TO TAIL OF KEYBOARD BUFFER
KB_BUFFER	DW	16 DUP(?)	; ROOM FOR 15 ENTRIES
KB_BUFFER_END	LABEL	WORD

;------ HEAD = TAIL INDICATES THAT THE BUFFER IS EMPTY

NUM_KEY 	EQU	69		; SCAN CODE FOR NUMBER LOCK
SCROLL_KEY	EQU	70		; SCROLL LOCK KEY
ALT_KEY 	EQU	56		; ALTERNATE SHIFT KEY SCAN CODE
CTL_KEY 	EQU	29		; SCAN CODE FOR CONTROL KEY
CAPS_KEY	EQU	58		; SCAN CODE FOR SHIFT LOCK
LEFT_KEY	EQU	42		; SCAN CODE FOR LEFT SHIFT
RIGHT_KEY	EQU	54		; SCAN CODE FOR RIGHT SHIFT
INS_KEY 	EQU	82		; SCAN CODE FOR INSERT KEY
DEL_KEY 	EQU	83		; SCAN CODE FOR DELETE KEY

;----------------------------------------
;	POST DATA AREA			:
;----------------------------------------
IO_ROM_INIT	DW	?		; PNTR TO OPTIONAL I/O ROM INIT ROUTINE
IO_ROM_SEG	DW	?		; POINTER TO IO ROM SEGMENT
;O MONTADOR ORIGINAL DA IBM ACEITA QUE DOIS LABELS DE TABELAS
;REALOCAVEIS SEJA SOMADO(NOVAMENTE)
INTR_FLAG		DB	06BH		; FLAG TO INDICATE AN INTERRUPT HAPPEND
INTR_FLAG_OFFSET	EQU	041H		; FLAG TO INDICATE AN INTERRUPT HAPPEND


;----------------------------------------
;	TIMER DATA AREA 		:
;----------------------------------------
TIMER_LOW	DW	?		; LOW WORD OF TIMER COUNT
TIMER_HIGH	DW	?		; HIGH WORD OF TIMER COUNT
TIMER_OFL	DB	?		; TIMER HAS ROLLED OVER SINCE LAST READ
;COUNTS_SEC	EQU	18
;COUNTS_MIN	EQU	1092
;COUNTS_HOUR	EQU	65543
;COUNTS_DAY	EQU	1573040 = 1800B0H

;----------------------------------------
;	   SYSTEM DATA AREA		:
;----------------------------------------
BIOS_BREAK	DB	?		; BIT 7 = 1 IF BREAK KEY HAS BEEN HIT
RESET_FLAG	DW	?		; WORD = 1234H IF KEYBOARD RESET UNDERWAY
;----------------------------------------
;	  FIXED DISK DATA AREA		:
;----------------------------------------
		DW	?		;
		DW	?		;

;--------------------------------------------------------
;	PRINTER AND RS232 TIME-OUT VARIABLES		:
;--------------------------------------------------------
PRINT_TIM_OUT	DB	4 DUP(?)
RS232_TIM_OUT	DB	4 DUP(?)
DATA ENDS
;----------------------------------------
;	EXTRA DATA AREA 		:
;----------------------------------------
XXDATA	SEGMENT AT 50H
STATUS_BYTE	DB	?
XXDATA		ENDS


.CODE

;----------------------------------------
;	DATA DEFINITIONS		:
;----------------------------------------

C1	DW	C11		; RETURN ADDRESS
;C2	DW	C24		; RETURN ADDRESS FOR DUMMY STACK


ORG 0E0000h
uart_int:
    in  al,10h
    out 10h,al
    mov ds:[bx],al 
    add bx,2
   ;finaliza a interrupcao	
    mov al,20h          
    out 80h,al
    iret


org 0F0000h

init_bios:


init_8251:


;---------------------------------------------
; Parametrizar 8251
;---------------------------------------------
    ; Resetar 8251
    ;Bit	Name	Value	Meaning
    ;D7	EH	0	Hunt mode disabled (sync mode only)
    ;D6	IR	1	Internal Reset
    ;D5	RTS	0	RTS inactive
    ;D4	ER	0	Reset error flags disabled
    ;D3	SBRK	0	Don't transmit BREAK
    ;D2	RxE	0	Receiver disabled
    ;D1	DTR	0	DTR inactive
    ;D0	TxEN	0	Transmitter disabled
    mov al,40h
    out 12h,al
    mov al,40h
    out 12h,al
    mov al,40h
    out 12h,al
    mov al,40h
    out 12h,al

    ; Datasheet do 8251A recomenda inclusao de wait states apos resetar.
    ;mov cx,1000
    ;delay:
    ;    loop delay

    ; 8-N-1 Baud 9600 para 5Mhz
    ;D1 D0	Meaning
    ;00	Synchronous
    ;01	×1
    ;10	×16
    ;11	×64
    ;D3 D2	Bits Character length
    ;00	5 bits
    ;01	6 bits
    ;10	7 bits
    ;11	8 bits
    ;D4
    ;Parity Enable
    ;0
    ;D5
    ;Even/Odd parity (1/0)
    ;X Don't care
    ;D7-D6
    ;Stop bits
    ;01 -> 1 stop bit
    ;10 -> 1.5 stop bits
    ;11 -> 2 stop bits
    mov al,4eh
    out 12h,al

    ; Comando word
    mov al,15h
    out 12h,al



;--------------------------------------------------------
;	8253 TIMER CHECKOUT				:
;DESCRIPTION						:
;	VERIFY THAT THE SYSTEM TIMER (0) DOESN'T COUNT  :
;	TOO FAST OR TOO SLOW.
; COMENTADO PARA POSTERIOR AVALIACAO			:
;--------------------------------------------------------
D7:
;	MOV	DATA_AREA[OFFSET MFG_ERR_FLAG],02H
					; <><><><><><><><><><><><><><><><>
;					; <><><>TIMER CHECKPOINT (2)<><><>
;	MOV	AL,0FEH 		; MASK ALL INTRS EXCEPT LVL 0
;	OUT	INTA01,AL		; WRITE THE 8259 IMR
;	MOV	AL,00010000B		; SEL TIM 0, LSB, MODE 0, BINARY
;	OUT	TIM_CTL,AL		; WRITE TIMER CONTROL MODE REG
;	MOV	CX,16H			; SET PGM LOOP CNT
;	MOV	AL,CL			; SET TIMER 0 CNT REG
;	OUT	TIMER0,AL		; WRITE TIMER 0 CNT REG


;--------------------------------------------------------
;	INICIALIZAR 8259 PIC				:
;--------------------------------------------------------
C25:

;ICW1
;Bit  Valor  Descricao
;D4    1     Start Initialization - Vai configurar ICW4 na sequencia. O byte enviado agora é ICW1
;D3    0     0 Edge triggered / 1 Level triggered
;D2    0     Call address interval (ignored in 8086 mode) somente para 8080-8085.
;D1    1     Single PIC (Pula ICW3)
;D0    1     ICW4 will follow

mov al,13h
out INTA00,al

;ICW2
;Interrupt Vector Base (onde começa o vetor de interrupcao)
;IRQ0 → INT 20h
;IRQ1 → INT 21h
;IRQ2 → INT 22h
;...
;IRQ7 → INT 27h
;0x00 até 0x1F é reservado pela Intel (NMI, div por 0, etc...)
;0x20 a 0x27 e usado pelo MS-DOS e pela IBM (caso queiramos portar nosso computador pra esse OS)

mov al,20h
out INTA01,al

;ICW4
;Bit  Valor  Descricao
;D0     1    8086 mode 1 = 8086/8088 mode, 0 = 8080/8085 mode
;D1     0    Normal EOI Automatic End Of Interrupt
;D2     0    Master/slave when buffered disabled
;D3     0    Buffered mode disabled
;D4     0    Special Fully Nested Mode disabled

mov al,01h
out INTA01,al


;OCW1(IMR)
;11101111b = FDh habilita so o serial (IRQ4); Compativel com MS-DOS

mov al,0EFh
out INTA01,al

;--------------------------------------------------------
;	8259 INTERRUPT CONTROLLER TEST			:
;DESCRIPTION						:
;	READ/WRITE THE INTERRUPT MASK REGISTER (IMR)	:
;	WITH ALL ONES AND ZEROES. ENABLE SYSTEM 	:
;	INTERRUPTS.  MASK DEVICE INTERRUPTS OFF. CHECK	:
;	FOR HOT INTERRUPTS (UNEXPECTED).		:
;--------------------------------------------------------
	ASSUME	DS:ABS0
C21:	POP	DS

;----- TEST THE IMR REGISTER

C21A:	MOV	DATA_AREA[OFFSET MFG_ERR_FLAG],05H
					; <><><><><><><><><><><><>
					; <><><>CHECKPOINT 5<><><>
	MOV	AL,0			; SET IMR TO ZERO
	OUT	INTA01,AL
	IN	AL,INTA01		; READ IMR
	OR	AL,AL			; IMR = 0?
	JNZ	D6			; GO TO ERR ROUTINE IF NOT 0
C21B:
	MOV	AL,0FFH 		; DISABLE DEVICE INTERRUPTS
	OUT	INTA01,AL		; WRITE TO IMR
	OUT	INTA01,AL		; REPETIDO POIS ESTRANHAMENTE O IMR NAO CONSEGUE SER SETADO NO PRIMEIRO OUT
	IN	AL,INTA01		; READ IMR
	ADD	AL,1			; ALL IMR BITS ON?
	JNZ	D6			; NO - GO TO ERR ROUTINE



;----- CHECK FOR HOT INTERRUPTS

;----- INTERRUPTS ARE MASKED OFF.  CHECK THAT NO INTERRUPTS OCCUR

	MOV	DATA_AREA[INTR_FLAG_OFFSET],AL	; CLEAR INTERRUPT FLAG
	STI				; ENABLE EXTERNAL INTERRUPTS
	SUB	CX,CX			; WAIT 1 SEC FOR ANY INTRS THAT
D4:
	LOOP	D4			; MIGHT OCCUR
D5:
	LOOP	D5
	CMP	DATA_AREA[INTR_FLAG_OFFSET],00H ; DID ANY INTERRUPTS OCCUR?
	MOV	AL,0EFH			; ATIVANDO APENAS A INTERRUPCAO SERIAL (IRQ4)
	OUT	INTA01,AL
;	JZ	D7			; NO - GO TO NEXT TEST
	JZ	init_8253		; MODIFICADO. PULA PARA A CONFIGURACAO DO 8253
D6:
;COMENTANDO POIS NÃO FOI IMPLEMENTADO AINDA
;	MOV	SI,OFFSET E0		; DISPLAY 101 ERROR
;	CALL	E_MSG
	CLI
	HLT				; HALT THE SYSTEM

;--------------------------------------------------------
;	INICIALIZAR 8253 PIT				:
;--------------------------------------------------------
init_8253:

;Bits			Descrição
;D7–D6 (SC1:SC0)	Seleciona contador 0, 1 ou 2
;D5–D4 (RW1:RW0)	Seleciona byte baixo, byte alto, ou byte baixo seguido de byte alto ou comando de latch da contagem atual
;D3–D1 (M2:M0)		Seleciona o modo de contagem.
;D0 (BCD)		0 seleciona contador binário; 1 seleciona contador BCD.

; Configura Contador 0:
; Mode 3, binary, low byte followed by high byte

MOV AL, 36H	  ; Contador 0 Modo 3(Onda quadrada), contador binário
OUT 46H, AL       ; Word de Controle

;Carrega a contagem no Contador 0
MOV AL, 0CH      ; Byte baixo
OUT 40H, AL

MOV AL, 00H       ; Byte alto
OUT 40H, AL

;setando RxRDY para int24h
    mov si,0000h
    mov ax, UART_OFFSET
    mov [si+90h], ax
    mov ax, UART_SEGMENT
    mov [si+92h], ax
    sti


RESET	LABEL	FAR
START:	CLI				; DISABLE INTERRUPTS
	MOV	AH,0D5H 		; SET SF, CF, ZF, AND AF FLAGS ON
	SAHF
	JNC	ERR01			; GO TO ERR ROUTINE IF CF NOT SET
	JNZ	ERR01			; GO TO ERR ROUTINE IF ZF NOT SET
	JNP	ERR01			; GO TO ERR ROUTINE IF PF NOT SET
	JNS	ERR01			; GO TO ERR ROUTINE IF SF NOT SET
	LAHF				; LOAD FLAG IMAGE TO AH
	MOV	CL,5			; LOAD CNT REG WITH SHIFT CNT
	SHR	AH,CL			; SHIFT AF INTO CARRY BIT POS
	JNC	ERR01			; SO TO ERR ROUTINE IF AF NOT SET
	MOV	AL,40H			; SET THE OF FLAG ON
	SHL	AL,1			; SETUP FOR TESTING
	JNO	ERR01			; GO TO ERR ROUTINE IF OF NOT SET
	XOR	AH,AH			; SET AH = 0
	SAHF				; CLEAR SF, CF, ZF, AND PF
	JBE	ERR01			; GO TO ERR ROUTINE IF CF ON
					; OR TO TO ERR ROUTINE IF ZF ON
	JS	ERR01			; GO TO ERR ROUTINE IF SF ON
	JP	ERR01			; GO TO ERR ROUTINE IF PF ON
	LAHF				; LOAD FLAG IMAGE TO AH
	MOV	CL,5			; LOAD CNT REG WITH SHIFT CNT
	SHR	AH,CL			; SHIFT AH INTO CARRY BIT POS
	JC	ERR01			; GO TO ERR ROUTINE IF ON
	SHL	AH,1			; CHECK THAT OF IS CLEAR
	JO	ERR01			; GO TO ERR ROUTINE IF ON

;----- READ/WRITE THE 8088 GENERAL AND SEGMENTATION REGISTERS
;      WITH ALL ONE'S AND ZEROES'S.

	MOV	AX,0FFFFH		; SETUP ONE'S PATTERN IN AX
	STC
C8:	MOV	DS,AX			; WRITE PATTERN TO ALL REGS
	MOV	BX,DS
	MOV	ES,BX
	MOV	CX,ES
	MOV	SS,CX
	MOV	DX,SS
	MOV	SP,DX
	MOV	BP,SP
	MOV	SI,BP
	MOV	DI,SI
	JNC	C9			; TST1A
	XOR	AX,DI			; PATTERN MAKE IT THRU ALL REGS
	JNZ	ERR01			; NO - GO TO ERR ROUTINE
	CLC
	JMP	C8
C9:					; TST1A
	OR	AX,DI			; ZERO PATTERN MAKE IT THRU?
	JZ	C10			; YES - GO TO NEXT TEST
ERR01:	HLT				; HALT SYSTEM
;----------------------------------------
;	ROS CHECKSUM TEST I		:
;DESCRIPTION				:
;	A CHECKSUM IS DONE FOR THE 8K	:
;	ROS MODULE CONTAINING POD AND	:
;	BIOS.				:
;----------------------------------------
C10:
	MOV	AX,CS			; SETUP SS SEG REG
	MOV	SS,AX
	MOV	DS,AX			; SET UP DATA SEG TO POINT TO
					; ROM ADDRESS
	CLD				; SET DIRECTION FLAG TO INC.
;	ASSUME	SS:CODE
	MOV	BX,0E000H		; SETUP STARTING ROS ADDR
;	MOV	SP,OFFSET C1		; SETUP RETURN ADDRESS
	MOV	SP,0FFFFh		; SETUP RETURN ADDRESS

	JMP	ROS_CHECKSUM
C11:	JNE	ERR01			; HALT SYSTEM IF ERROR


;--------------------------------------------------------
;	TIMER 1 FUNCTIONS OK. WRITE/READ THE CURRENT	:
;	ADDRESS AND WORD COUNT REGISTERS FOR ALL	:
;	CHANNELS.  INITIALIZE AND START DMA FOR MEMORY	:
;	REFRESH.					:
;--------------------------------------------------------
;----------------------------------------
;	ROS CHECKSUM SUBROUTINE 	:
;----------------------------------------
ROS_CHECKSUM	PROC	NEAR		; NEXT_ROS_MODULE
	MOV	CX,0fffh 		; NUMBER OF BYTES TO ADD
ROS_CHECKSUM_CNT:			; ENTRY FOR OPTIONAL ROS TEST
	XOR	AL,AL
C26:
	ADD	AL,DS:[BX]		;CHECA OS ÚLTIMOS 64KBYTES DA MEMORIA
	INC	BX			; POINT TO NEXT BYTE
	LOOP	C26			; ADD ALL BYTES IN ROS MODULE
	OR	AL,AL			; SUM = 0?
	RET

	MOV AX,0E000H			; APONTANDO DS PARA E0000H
	MOV DS,AX
	MOV	CX,0fffh 		; NUMBER OF BYTES TO ADD
C26a:
	ADD	AL,DS:[BX]		;CHECA OS PRIMEIROS 64KBYTES DA MEMORIA
	INC	BX			; POINT TO NEXT BYTE
	LOOP	C26a			; ADD ALL BYTES IN ROS MODULE
	OR	AL,AL			; SUM = 0?
	RET

ROS_CHECKSUM	ENDP

;--------------------------------------------------------
;	VOLTA AO NOSSO CÓDIGO
;--------------------------------------------------------
	STI				;ativa interrupcoes novamente
	mov ax,0000h
	mov ss,ax
	mov ds,ax
	mov sp,0030h

loop_principal:
    nop
    jmp     loop_principal


org 0FFFF0h

inicio:
	mov ax,0000h
	mov ds,ax
	mov ss,ax	
	mov bx,0100h
	jmp far ptr init_bios

end inicio