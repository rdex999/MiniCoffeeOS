;
; ---------- [ FUNCTION FOR CLOSING AN OPENED FILE ] ----------
;

%ifndef FCLOSE_ASM
%define FCLOSE_ASM

; Close an opened file
; PARAMETERS
;   - 0) DI   => File handle
; RETURNS
;   - 0) In AX, 0 success and EOF (0FFFFh) on failure
fclose:
  push bp
  mov bp, sp
  sub sp, 6

  mov [bp - 2], ds
  mov [bp - 4], es

  mov bx, KERNEL_SEGMENT                          ; Set DS to kernel segment so we can access the openFiles array
  mov ds, bx                                      ;

  ; Here we check if its an invalid handle
  cmp di, FILE_OPEN_LEN                           ; Check if the file handle (an index into openFiles) is greater than its length
  ja .err                                         ; If it is, then its not a valid handle and we return with an error (greater because handle starts from 1)

  test di, di                                     ; Check if the handle is 0 (an invalid handle is null)
  jz .err                                         ; If null then return an error

  ; Here we multiply the handle (an index) by the size of an open file descriptor
  ; to get the offset into the openFiles array
  mov ax, di                                      ; Get file handle in AX
  dec ax                                          ; Decrement handle by 1, because it starts from 1 and an index start from 0

  mov bx, FILE_OPEN_SIZEOF                        ; Get the size of an open file descriptor
  mul bx                                          ; Multiply index by the size of an open file descriptor to get the offset into openFiles

  lea si, [openFiles]                             ; Get pointer to the first element of openFiles
  add si, ax                                      ; Add to the pointer the offset we just calculated
  mov [bp - 6], si
  
  cmp word ds:[si + FILE_OPEN_ENTRY256 + 26], 0   ; Check if the file is open
  je .err                                         ; If the file is not open then return an error

  sub sp, ds:[bpb_bytesPerSector]
  
  mov di, ds:[si + FILE_OPEN_ENTRY_LBA16]

  mov si, 1
  
  mov bx, ss
  mov es, bx
  mov bx, sp
  call readDisk
  test ax, ax
  jnz .err

  mov bx, KERNEL_SEGMENT
  mov ds, bx
  mov si, [bp - 6]
  
  mov bx, ss
  mov es, bx
  mov di, sp
  add di, ds:[si + FILE_OPEN_ENTRY_OFFSET16]

  add si, FILE_OPEN_ENTRY256

  mov dx, 32
  call memcpy

  mov bx, ss
  mov ds, bx
  mov si, sp

  mov bx, KERNEL_SEGMENT
  mov es, bx
  mov di, [bp - 6]
  mov di, es:[di + FILE_OPEN_ENTRY_LBA16]

  mov dx, 1
  call writeDisk
  test ax, ax
  jnz .err

  mov bx, KERNEL_SEGMENT
  mov ds, bx
  mov si, [bp - 6]

  mov word ds:[si + FILE_OPEN_ENTRY256 + 26], 0   ; Set the files first cluster number to 0, to indicate this slot is empty

  xor ax, ax                                      ; Zero out result, because we return 0 on success

.end:
  mov ds, [bp - 2]
  mov es, [bp - 4]
  mov sp, bp
  pop bp
  ret

.err:
  mov ax, EOF
  jmp .end

%endif