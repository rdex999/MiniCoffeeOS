;
; ---------- [ FILE TO AN OPEN FILE ] ---------
;

%ifndef FWRITE_ASM
%define FWRITE_ASM

; Write to the current position in a file.
; PARAMS
;   - 0) ES:DI  => The buffer of data to be written to the file
;   - 1) SI     => The amount of bytes to write to the file
;   - 2) DX     => A handle to the file
; RETURNS
;   - 0) In AX, the amount of bytes written. Can be less than the requested amount if an error occurs
fwrite:
  push bp                                 ; Save stack frame
  mov bp, sp                              ;
  sub sp, 6                               ; Allocate space for local stuff

  mov [bp - 2], es                        ; Save data buffer pointer
  mov [bp - 4], di                        ; Save its offset
  mov [bp - 6], si                        ; Save the amount of bytes to write

  mov bx, KERNEL_SEGMENT                  ; Set ES to the kernels segment so we can access the openFiles array
  mov es, bx                              ;

  ; Check if the handle is valid
  test dx, dx                             ; Check if the handle is null
  jz .err                                 ; If it is, return 0

  cmp dx, FILE_OPEN_LEN                   ; Check if the handle is greater than the length of the openFiles array
  ja .err                                 ; If it is, return 0

  ; Get a pointer to the file descriptor in the openFiles array
  mov ax, dx                              ; Get the handle in AX
  dec ax                                  ; Decrement it by one, because handles start from 1 and its actualy an index into openFiles

  mov bx, FILE_OPEN_SIZEOF                ; Get the size of a single file descriptor
  mul bx                                  ; Multiply the index by it

  lea di, [openFiles]                     ; Get a pointer to the openFiles array
  add di, ax                              ; Add to it the calculated offset

  mov al, es:[di + FILE_OPEN_ACCESS8]     ; Get the files access

  cmp al, FILE_OPEN_ACCESS_READ
  je .err

  cmp al, FILE_OPEN_ACCESS_READ
  je .err


  ; Check the files size, and if we need to add clusters




  mov dx, es:[di + FILE_OPEN_POS16]
  mov di, es:[di + FILE_OPEN_ENTRY256 + 26]
  mov cx, [bp - 6]
  mov es, [bp - 2]
  mov di, [bp - 4]
  call writeClusterBytes



.end:
  mov es, [bp - 2]                        ; Restore used segments
  mov sp, bp                              ; Restore stack frame
  pop bp                                  ;
  ret

.err:
  xor ax, ax                              ; If there was an error, return null
  jmp .end

%endif