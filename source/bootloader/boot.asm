bits 16

org 7c00h

%include "source/bootloader/macros/macros.asm"

;
; ---------- [ BIOS PARAMETER BLOCK ] ----------
;

; [[ BPB ]]

; first three bytes are a jump (to skip this data declaration) and a NOP
jmp short 3Ch
nop

bpb_oemId:                    db "MSWIN4.1"
bpb_bytesPerSector:           dw 512
bpb_sectorPerCluster:         db 1
bpb_reservedSectors:          dw 1
bpb_FATs:                     db 2
bpb_rootDirectoryEntries:     dw 224
bpb_sectorsInVolume:          dw 2880
bpb_mediaDescriptorType:      db 240
bpb_sectorsPerFAT:            dw 9
bpb_sectorsPerTrack:          dw 18
bpb_numberOfHeadsOrSides:     dw 2
bpb_hiddenSectorsCount:       dw 0
                              dw 0
bpb_largeSectorCount:         dw 0
                              dw 0

;
; ---------- [ EXTENDED BIOS PARAMETER BLOCK ] ----------
;

; [[ EBPB ]]

ebpb_driveNumber:              db 0
ebpb_flags:                    db 0
ebpb_signature:                db 29h
ebpb_volumeID:                 dw 0
                              dw 0
ebpb_volumeLable:              db "MY KERNEL  " ; 11 bytes
;ebpb_systemID:                 db "MYKERNEL"    ; 8 bytes
ebpb_systemID:                 db "KERNEL  "    ; 8 bytes

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

  ; set video mode (80x25)
  xor ah, ah                ; ah = 0
  mov al, 3                 ; text mode on 80x25
  int 10h

  lea di, [loadingMsg]
  call printStr

  GET_ROOT_DIR_OFFSET
  mov si, ax
  GET_ROOT_DIR_SIZE

  mov di, si
  mov si, ax
  mov bx, buffer
  call readDisk

  PRINT_STR11 buffer+32



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

; (510 - <size of segment>)/2 ( fill rest of sector with zeros and last to bytes are 0AA55h )
times 510 - ($ - $$) db 0

dw 0AA55h   ; magic number%

buffer: