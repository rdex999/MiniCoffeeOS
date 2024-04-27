;
; --------- [ WRITE A DATA BUFFER INTO A CLUSTER CHAIN ] ----------
;

%ifndef WRITE_CLUSTER_BYTES_ASM
%define WRITE_CLUSTER_BYTES_ASM

; Write a data buffer to a cluster chain on a given offset
; PARAMETERS
;   - 0) DI     => The files first cluster number
;   - 1) DS:SI  => The data buffer
;   - 2) DX     => The offset to write the data on the file (in bytes)
;   - 3) CX     => The amount of bytes to write to the file, from the buffer
; RETURNS
;   - 0) In AX, the amount of bytes written
writeClusterBytes:
  push bp
  mov bp, sp 
  sub sp, 19

  ; *(bp - 2)     - Files first cluster number
  ; *(bp - 4)     - Data buffer to write (segment)
  ; *(bp - 6)     - Data buffer to write (offset)
  ; *(bp - 8)     - Bytes offset to write on
  ; *(bp - 10)    - Amount of bytes to write
  ; *(bp - 12)    - Old GS segment
  ; *(bp - 14)    - Sector buffer offset (segment is SS)
  ; *(bp - 16)    - Current LBA address
  ; *(bp - 17)    - Sectors left in cluster
  ; *(bp - 19)    - Bytes read so far

  mov [bp - 2], di                          ; Store arguments   // Store first cluster number
  mov [bp - 4], ds                          ; Store buffer segment
  mov [bp - 6], si                          ; Store buffer offset
  mov [bp - 8], dx                          ; Store bytes offset
  mov [bp - 10], cx                         ; Store amount of bytes to write
  mov [bp - 12], gs                         ; Store old GS segment
  mov word [bp - 19], 0                     ; Initialize bytes written so far to 0

  mov bx, KERNEL_SEGMENT                    ; Set GS to kernel segment so we can access kernel variables
  mov gs, bx                                ;

  sub sp, gs:[bpb_bytesPerSector]           ; Allocate space for 1 sector on the stack
  mov [bp - 14], sp                         ; Store sector buffer offset


.success:
  mov ax, [bp - 19]                         ; Get amount of bytes written

.end:
  mov gs, [bp - 12]                         ; Restore old GS segment
  mov ds, [bp - 4]                          ; Restore old DS segment
  mov sp, bp                                ; Restore stack frame
  pop bp                                    ;
  ret

.err:
  xor ax, ax                                ; Return 0 on error (0 bytes written)
  jmp .end

%endif