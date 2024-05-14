;
; --------- [ READ BYTES FROM THE ROOT DIRECTORY ON A GIVEN OFFSET ] ---------
;

%ifndef READ_ROOT_DIR_BYTES_ASM
%define READ_ROOT_DIR_BYTES_ASM

; =================================================================================
; Read N bytes from the root directory, on a given offset (like readClusterBytes)
; PARAMETERS
;   - 0) ES:DI  => Buffer to store the data in
;   - 1) SI     => Byte offset to read from
;   - 2) DX     => Amount of bytes to read
; RETURNS
;   - 0) AX     => The amount of bytes read
; =================================================================================
readRootDirBytes:
  push bp
  mov bp, sp
  sub sp, 10

  ; *(bp - 2)       - Buffer segment
  ; *(bp - 4)       - Buffer offset
  ; *(bp - 6)       - Byte offset to read from
  ; *(bp - 8)       - Amount of bytes to read
  ; *(bp - 10)      - Current LBA in root directory

  mov [bp - 2], es
  mov [bp - 4], di
  mov [bp - 8], dx

  mov ax, si
  mov bx, 512
  xor dx, dx
  div bx

  mov [bp - 10], ax
  mov [bp - 6], dx

  push ds
  mov bx, KERNEL_SEGMENT
  mov ds, bx

  GET_ROOT_DIR_OFFSET
  pop ds

  add [bp - 10], ax










.end:
  mov sp, bp
  pop bp
  ret

%endif