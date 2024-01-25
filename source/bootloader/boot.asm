bits 16

;
; ------ [ CODE SECTION ] ------
;

org 7c00h

 
  ;TODO: Ask David about this stf (about segment registers)
  mov ax, 07c0h
  mov ss, ax
  mov sp, 03feh ; top of the stack.

  ; set data segment:
  xor ax, ax
  mov ds, ax

  ; set video mode (80x25)
  xor ah, ah    ; ah = 0
  mov al, 3   ; text mode on 80x25
  int 10h

  lea di, [welcomeMsg]
  call printStr

  ; load kernel to memory 
  mov ah, 2   ; read interrupt
  mov al, 10  ; number of sectors to read
  xor ch, ch  ; cylinder 0
  mov cl, 2   ; sector 2
  xor dx, dx  ; head in DH, drive number in DL // set both to 0

  ; es:bx points to receiving data buffer:
  mov bx, 0800h   
  mov es, bx
  xor bx, bx

  ; Perform BIOS interrupt
  int 13h

  ; jump to kernel.
  jmp 0800h:0000h

  INT 19h      ; reboot

;
; ------ [ PROCEDURES ] ------
;

; prints a string from DI (null terminated)
printStr: ;PROC

printStr_loop:
  mov ah, 0Eh       ; prints a character and advances the cursor
  mov al, [di]      ; al = *di
  int 10h           ; BIOS interrupt
  inc di
  test al, al         ; like cmp AL, o // but more efficient
  jnz printStr_loop
  
  ret
;printStr ENDP

;
; ------ [ DATA SECTION ] ------
;

welcomeMsg: db "Loading kernel into memory and booting...", 10, 13, 0

; (510 - <size of segment>)/2 ( fill rest of sector with zeros and last to bytes are 0AA55h )
times 510 - ($ - $$) db 0

dw 0AA55h   ; magic number%
