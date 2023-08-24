org 0x7C00
bits 16
; Thanks to https://www.youtube.com/watch?v=9t-SPC7Tczc&list=PLFjM7v6KGMpiH2G-kT781ByCNC_0pKpPN for all the good info and wisdom!

%define ENDL `\r\n`

;
; FAT12 Header
;

jmp short start
nop

bdb_oem:                       db 'MSWIN4.1'        ;8 bytes to ID the util that made the FS
bdb_bytes_pre_sector:          dw 512
bdb_sectors_pre_cluster:       db 1
bdb_reserved_sectors:          dw 1                 ;sectors for boot
bdb_fat_count:                 db 2                 ;num of FATs on the storage media
bdb_dir_entries_count:         dw 0E0h
bdb_total_sectors:             dw 2880              ;2880 * 512 = 1.44MB
bdb_media_descriptor_type:     db 0F0h              ;F0 = 3.5" floppy disk
bdb_sectors_pre_fat:           dw 9
bdb_sectors_pre_track:         dw 18
bdb_heads:                     dw 2
bdb_hidden_sectors:            dd 0
bdb_large_sector_count:        dd 0

; extended header fields

ebr_drive_number:              db 0                     ;0x00 = floppy, 0x80 = hdd, useless
                               db 0                     ;reserved
ebr_signature:                 db 29h                   ; 29 or 28
ebr_volume_id:                 db 13h, 37h, 87h, 12h    ;serial number
ebr_volume_label:              db 'MyOS v0.0.1'         ;11bytes, pad with spaces if needed
ebr_system_id:                 db 'FAT12   '            ;8bytes

;
; CODE GOES AFTER THIS
;

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
	mov ah, 0x0E     ;set channel command to run (in our case to print an ASCII char to tty)
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
	
	;read something from the floppy
	;BIOS should set dl to drive number
	mov [ebr_drive_number], dl
	mov ax, 1                                                             ; LBA=1, second sector from disk (zero based like all good things should be)
	mov cl, 1                                                             ; read 1 sector
	mov bx, 0x7E00                                                        ; data should be loaded after bootloader
	call read_disk

	;print greeting
	mov si, msg_greeting
	call puts

	cli 
	hlt 

; 
; Error handlers
;

floppy_error:
	mov si, msg_floppy_error
	call puts

wait_key_and_reboot:
	mov ah, 0
	int 16h                                                               ; wait for keypress
	jmp 0FFFFh:0                                                          ; jump to the beginning of BIOS, should effectively reboot the system

.halt:
	cli                                                                   ; disables interupts, this way CPU can't get out of "halt"
	hlt

;
; Disk functions
;

; Convert an LBA address to a CHS address
; Params:
;   - ax: LBA addressc
; Returns:
;   - cx[bits 0-5]: sector number
;   - cx[bits 6-15]: cylinder
;   - dh: head

lba_to_chs:
	;save state
	push ax
	push dx

	xor dx, dx                                                              ; zero out dx
	div word [bdb_sectors_pre_track]                                        ; ax = LBA / SectorsPreTrack
	                                                                        ; dx = LBA % SectorsPreTrack
	inc dx                                                                  ; dx = (LBA % SectorsPreTrack) + 1 = sector
	mov cx, dx                                                              ; cx = sector 

	xor dx, dx                                                              ; zero dx back out again
	div word [bdb_heads]                                                    ; ax = (LBA / SectorsPreTrack) / Heads = cylinder
	                                                                        ; dx = (LBA / SectorsPreTrack) % Heads = head
	mov dh, dl                                                              ; dh = head
	mov ch, al                                                              ; ch = cylinder (lower 8 bits)
	shl ah, 6                                                               ; bit shift the high bits so we can or them in
	or cl, ah                                                               ; or the bit shifted high bits where they belong in cx
	
	;clean up
	pop ax
	mov dl, al                                                              ; ONLY RESTORE dl SINCE PART OF THE RET IS IN DH!!!
	pop ax
	ret


; Read sectors from disk
; Params:
;   - ax: LBA address
;   - cl: num of sectors to read (128 limit)
;   - dl: drive number
;   - es:bx: memory address where to store read data

read_disk:
	push di                                                                ; save non-param register we use 

	push cx                                                                ; back up the cl Params
	call lba_to_chs
	pop ax                                                                 ; and now al = num of sectors to read

	mov ah, 02h
	mov di, 3                                                              ;retry count 

.retry_read:
	pusha                                                                  ;save all registers, no telling what BIOS may modify
	stc                                                                    ;some BIOS' don't set the carry flag so we make sure it is set 
	int 13h                                                                ;carry flag cleared == successful read
	jnc .read_done
	;if failed
	popa
	call disk_reset

	dec di
	test di, di 
	jnz .retry_read

.read_failed:
	jmp floppy_error

.read_done:
	popa

	pop di                                                                ; restore non-param register we used
	ret 

;
; Resets Disk's controller
; Params:
;   - dl: drive number

disk_reset:
	pusha
	mov ah, 0
	stc 
	int 13h
	jc floppy_error
	popa
	ret


msg_greeting:     db 'Welcome to System_Failure OS!', ENDL, 0
msg_floppy_error: db 'Read error on floppy disk!', ENDL, 0

;Pad with the special sauce that the Legacy BIOS will look for!
times 510-($-$$) db 0
dw 0AA55h
