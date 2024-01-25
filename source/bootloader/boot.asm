bits 16


org 7c00h

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
ebpb_systemID:                 db "MYKERNEL"    ; 8 bytes

;
; ------ [ CODE SECTION ] ------
;

 
  ;TODO: Ask David about this stf (about segment registers)
  mov ax, 07c0h
  mov ss, ax
  mov sp, 03feh ; top of the stack.

  ; set data segment:
  xor ax, ax
  mov ds, ax

  mov [ebpb_driveNumber], dl  ; BIOS passes drive number in DL

  ; set video mode (80x25)
  xor ah, ah    ; ah = 0
  mov al, 3   ; text mode on 80x25
  int 10h

  lea di, [loadingMsg]
  call printStr

  mov di, 1     ; LBA 1 = sector 2
  mov si, 10    ; read 10 sectors
  xor bx, bx      ;
  mov es, bx      ;
  mov bx, 7E00h   ; es:bx points to data buffer (7c00h + 512 = 7E00h) kernel will be rigth after the bootloader
  call readFromDisk


  ; jump to kernel.
  jmp 0800h:0000h

  INT 19h      ; reboot

;
; ------ [ PROCEDURES ] ------
;

; prints a string from DI (null terminated)
printStr:

printStr_loop:
  mov ah, 0Eh       ; prints a character and advances the cursor
  mov al, [di]      ; al = *di
  int 10h           ; BIOS interrupt
  inc di
  test al, al         ; like cmp AL, o // but more efficient
  jnz printStr_loop
  
  ret
;printStr ENDP


; converts LBA (Logical Block Address) to CHS (Cylinder Head Sector)
; PARAMS
;   - 1) DI => LBA address
; RETURNS
;   - CH => cylinder
;   - CL => sector
;   - DH => head
;   - DL => drive number (0 because using floppy)
lbaToChs:
  xor dx, dx                      ;
  mov ax, di                      ;
  mov bx, [bpb_sectorsPerTrack]   ;
  div bx                          ; AX = AX / BX ;; DX = %

  inc dx                          ;
  mov cl, dl                      ; sector = (LBA % sectorsPerTrack) + 1

  ; AX containes LBA/sectorsPerTrack
  xor dx, dx                            ;
  mov bx, [bpb_numberOfHeadsOrSides]    ;
  div bx                                ;
  mov dh, dl                            ; head = (LBA / sectorsPerTrack) % heads

  mov ch, al                            ; cylinder = (LBA / sectorsPerTrack) / heads
  ret


; reads data from the floppy disk.
; PARAMS
;   - 0) DI     => LBA address
;   - 1) SI     => number of sectors to read (8 bits)
;   - 2) ES:BX  => data buffer
; RETURNS
; CF = 1 if there was an error
; CF = 0 if ok
; AH = 0 if successful
; AL = number of sectors transfered
readFromDisk:
  push si   ;
  push bx   ; temporary save parameters
  
  call lbaToChs   ; convert LBA address to CHS. All return values are allready in place for BIOS interrupt

  pop bx      ; data buffer
  pop ax      ; AL => how many bytes to read

  mov ah, 2   ;
  int 13h     ; perform BIOS interrupt
  ret


;
; ------ [ DATA SECTION ] ------
;

loadingMsg: db "Loading kernel into memory and booting...", 10, 13, 0

; (510 - <size of segment>)/2 ( fill rest of sector with zeros and last to bytes are 0AA55h )
times 510 - ($ - $$) db 0

dw 0AA55h   ; magic number%
