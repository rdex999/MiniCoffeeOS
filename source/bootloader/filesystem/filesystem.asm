;
; ---------- [ FUNCTIONS FOR READING/WRITING FILES ] ----------
;

%ifndef FILESYSTEM_ASM
%define FILESYSTEM_ASM

%include "source/bootloader/macros/macros.asm"

; Converts LBA (Logical Block Address) to CHS (Cylinder Head Sector)
; PARAMS
;   - 1) DI => LBA address
; RETURNS
;   - CH => cylinder
;   - CL => sector
;   - DH => head
lbaToChs:
  mov ax, di                      ;
  mov bx, [bpb_sectorsPerTrack]   ; LBA / sectorsPerTrack
  xor dx, dx                      ;
  div bx                          ; AX = AX / BX ;; DX = %

  inc dx                          ;
  mov cl, dl                      ; sector = (LBA % sectorsPerTrack) + 1

  ; AX containes LBA/sectorsPerTrack
  mov bx, [bpb_numberOfHeadsOrSides]    ;
  xor dx, dx                            ;
  div bx                                ;
  mov dh, dl                            ; head = (LBA / sectorsPerTrack) % heads

  mov ch, al                            ; cylinder = (LBA / sectorsPerTrack) / heads
  ret


; Reads sectors from given LBA and stores data in a buffer.
; PARAMS
;   - 0) DI     => LBA
;   - 1) SI     => Amount of sectors to read
;   - 2) ES:BX  => Buffer
readDisk:
  pusha                         ; push all registers because BIOS messes them up
  push bx                       ; save data buffer
  call lbaToChs                 ; convert LBA from DI to CHS
  mov ax, si                    ; AL = number of sectors to read
  mov ah, 2                     ; read interrupt number
  mov dl, [ebpb_driveNumber]    ; get drive number
  pop bx                        ; restore data buffer
  int 13h                       ; read!
  popa                          ; restore all registers
  ret



; Searches for kernelFilename ("KERNEL  BIN") (11 bytes) and loads it to memory at buffer (buffer is a lable at the end of the boot sector 7E00h)
loadKernel:

  ret

%endif