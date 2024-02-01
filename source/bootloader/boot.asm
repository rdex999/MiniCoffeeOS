bits 16

org 7C00h

%include "source/bootloader/macros/macros.asm"

%define KERNEL_SEGMENT  2000h
%define KERNEL_OFFSET   0

%include "source/bootloader/bpbStruct/bpbStruct.asm"

;
; ------ [ CODE SECTION ] ------
;

  ; set segment registers
  xor ax, ax          ;
  mov ds, ax          ; set DS, ES, SS to 0
  mov es, ax          ;
  mov ss, ax          ;
  mov sp, 7C00h           ; set stack pointer to 7C00h

  push es
  push word afterCodeSegCheck
  retf
afterCodeSegCheck:


  mov [ebpb_driveNumber], dl  ; BIOS passes drive number in DL

  ; Get data from BIOS. this is more reliable. 
  push es                               ; BIOS will change ES, so save it for now
  mov ah, 8                             ; Interrupt number 8, get BIOS information
  int 13h                               ; Call BIOS
  pop es                                ; Restore ES

  xor ch, ch                            ; bpb_sectorsPerTrack is 16 bits
  mov [bpb_sectorsPerTrack], cx         ; Store number of sectors per track
  inc dh                                ; Increase head count, (Because BIOS doesnt do it)
  mov [bpb_numberOfHeadsOrSides], dh    ; Store head count


  ; set video mode (80x25)
  xor ah, ah                ; ah = 0, set screen mode.
  mov al, 3                 ; text mode on 80x25
  int 10h                   ; perform

  lea di, [loadingMsg]      ; print loading message
  call printStr

  lea di, kernelFilename              ; Load location of file name in DI (11 byte string)
  mov bx, KERNEL_SEGMENT              ; 
  mov es, bx                          ; ES = KernelSegment
  mov bx, KERNEL_OFFSET               ; BX = KernelOffset // ES:BX points to a location in memory to load kernel to.
  call readFile                       ; Load kernel into memory at ES:BX

  mov dl, [ebpb_driveNumber]
  mov ax, KERNEL_SEGMENT
  mov ds, ax
  mov es, ax

  jmp KERNEL_SEGMENT:KERNEL_OFFSET

  cli           ; disable interrupts
  hlt

;
; ------ [ PROCEDURES ] ------
;

%include "source/bootloader/filesystem/filesystem.asm"

; prints a string from DI (null terminated)
printStr:

printStr_loop:
  cmp byte [di], 0
  je printStr_end
  mov ah, 0Eh
  mov al, [di]
  int 10h
  inc di
  jmp printStr_loop


printStr_end:
  ret
;printStr ENDP

;
; ------ [ DATA SECTION ] ------
;

loadingMsg:         db "Loading kernel into memory and booting...", 10, 13, 0
kernelFilename:     db "KERNEL  BIN"
;kernelFilename:     db "TEST    TXT"        ;;;;;;;;;;;;; FOR DEBUG

; Fill rest of the file with zeros
times 510 - ($ - $$) db 0

dw 0AA55h   ; Magic number

buffer: