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
  sub sp, 8                               ; Allocate space for local stuff

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

  cmp word es:[di + FILE_OPEN_ENTRY256 + 26], 0
  je .err


  mov al, es:[di + FILE_OPEN_ACCESS8]     ; Get the files access

  cmp al, FILE_OPEN_ACCESS_READ
  je .err

  cmp al, FILE_OPEN_ACCESS_READ
  je .err

  mov [bp - 8], di
  ; Check the files size, and if we need to add clusters
  
  mov ax, es:[di + FILE_OPEN_POS16]
  add ax, [bp - 6]
  cmp ax, es:[di + FILE_OPEN_ENTRY256 + 28] 
  jbe .writeToFile

  sub ax, es:[di + FILE_OPEN_ENTRY256 + 28]

  ; pusha
  ; PRINT_CHAR 'I', VGA_TXT_YELLOW
  ; popa


  mov si, ax

  mov ax, es:[bpb_bytesPerSector]
  mov bl, es:[bpb_sectorPerCluster]
  xor bh, bh
  mul bx

  mov bx, ax
  mov ax, si 
  xor dx, dx
  div bx
  test ax, ax
  jz .writeToFile

  mov si, ax
  mov di, es:[di + FILE_OPEN_ENTRY256 + 26]
  call addClusters
  test ax, ax
  jz .err

.writeToFile:
  mov bx, KERNEL_SEGMENT
  mov es, bx
  mov ds, bx

  push ds
  mov di, [bp - 8] 
  mov dx, es:[di + FILE_OPEN_POS16]
  mov di, es:[di + FILE_OPEN_ENTRY256 + 26]
  mov cx, [bp - 6]
  mov ds, [bp - 2]
  mov si, [bp - 4]
  call writeClusterBytes
  pop ds

  mov di, [bp - 8]
  add es:[di + FILE_OPEN_POS16], ax

  mov bx, ax
  add bx, es:[di + FILE_OPEN_POS16]
  cmp bx, es:[di + FILE_OPEN_ENTRY256 + 28]
  jbe .end

  add es:[di + FILE_OPEN_ENTRY256 + 28], ax

.end:
  mov es, [bp - 2]                        ; Restore used segments
  mov sp, bp                              ; Restore stack frame
  pop bp                                  ;
  ret

.err:
  xor ax, ax                              ; If there was an error, return null
  jmp .end

%endif