org 0x7C00
bits 16
; Thanks to https://www.youtube.com/watch?v=9t-SPC7Tczc&list=PLFjM7v6KGMpiH2G-kT781ByCNC_0pKpPN for all the good info and wisdom!

%define ENDL `\r\n`

start:
	jmp main

;
; FUNCTION: Prints ds:si to the screen assuming it's a string
;
puts:
	push si
	push ax

.loop:
	lodsb            ;loads the next byte/char into al
	or al, al        ;verifies this new char (in al) isn't null
	jz .done         ;this jumps to .done if the zero flag was set by the or because al was null
	mov ah, 0x0E     ;set channel command to run (in our case to print an ASCII char to tty
	mov bh, 0        ;set page number
	int 0x10         ;call BIOS interupt for the Video channel
	jmp .loop        ;and then we loop

.done:
	pop ax
	pop si
	ret


;MAIN ENTRY
;This is the entry point to our bootloader
main:
	;setup data segments
	mov ax, 0       ;we can't write directly to ds/es
	mov ds, ax
	mov es, ax

	;setup stack
	mov ss, ax
	mov sp, 0x7C00 	;stack grows down from here (this way the stack shouldn't overwrite the OS)
	
	;print greeting
	mov si, msg_greeting
	call puts

	hlt

.halt:
	jmp .halt

msg_greeting: db 'Welcome to System_Failure OS!', ENDL, 0

;Pad with the special sauce that the Legacy BIOS will look for!
times 510-($-$$) db 0
dw 0AA55h
