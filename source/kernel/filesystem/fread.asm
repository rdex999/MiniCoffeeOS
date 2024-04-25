;
; ---------- [ READ FROM AN OPEN FILE AT THE READ POSITION ] ---------
;

%ifndef FREAD_ASM
%define FREAD_ASM

; Read from an open file at the current read position
; **Parameters are a bit different from the C fread.
; PARAMETERS
;   - 0) ES:DI  => Buffer to read data into
;   - 1) SI     => Number of bytes to read
;   - 2) DX     => File handle
; RETURNS
;   - 0) In AX, the amount of bytes read, can be less then the parameter if an error occurred.
fread:
  push bp                                           ; Save stack frame
  mov bp, sp                                        ;
  sub sp, 4                                         ; Allocate stack for local variables

  mov [bp - 2], ds                                  ; Save old DS segment
  mov [bp - 4], si                                  ; Save amount of bytes to read

  mov bx, KERNEL_SEGMENT                            ; Set DS to kernel segment so we can read correct values
  mov ds, bx                                        ;

  ; Check if the handle is valid
  test dx, dx                                       ; Check if the file handle is null (invalid)
  jz .err                                           ; If null then return 0

  cmp dx, FILE_OPEN_LEN                             ; Check if the handle is greater than the length of openFiles (which is invalid)
  ja .err                                           ; If it is then return 0

  ; If the handle is valid then continue, calculate the offset into openFiles and get the file first cluster number
  mov ax, dx                                        ; Get handle in AX as were multiplying it later
  dec ax                                            ; Decrement by 1, because the handle is an index which starts from 1

  mov bx, FILE_OPEN_SIZEOF                          ; Get the size of a file descriptor (in openFiles)
  mul bx                                            ; offset = index * sizeof(openFile);    // AX = offset

  lea si, [openFiles]                               ; Get a pointer to the start of the openFiles array
  add si, ax                                        ; Add the offset (AX) to the openFiles pointer

  cmp word ds:[si + FILE_OPEN_ENTRY256 + 26], 0     ; Check if the file is even open
  je .err                                           ; If the file is not open then return an error

  mov ax, ds:[si + FILE_OPEN_READ_POS16]
  add ax, [bp - 4]
  cmp ax, ds:[si + FILE_OPEN_ENTRY256 + 28]
  jae .setReadMax

  mov cx, [bp - 4]
  jmp .afterSetReadAmount

.setReadMax:
  mov cx, ds:[si + FILE_OPEN_ENTRY256 + 28]
  sub cx, ds:[si + FILE_OPEN_READ_POS16]

.afterSetReadAmount:

  ; Prepare arguments for readClusterBytes and read the file into the buffer
  ; Note: ES:DI, the destination buffer argument for readClusterBytes, is already set,
  ; as well as the amount of bytes to read (CX)

  push si
  mov dx, ds:[si + FILE_OPEN_READ_POS16]            ; Get the current read position in the file
  mov si, ds:[si + FILE_OPEN_ENTRY256 + 26]         ; Get the files first cluster number
  call readClusterBytes                             ; Read the file into the given buffer (the parameter, ES:DI)

  pop si
  add ds:[si + FILE_OPEN_READ_POS16], ax            ; Add the amount of bytes we read to the read position

.end:
  mov ds, [bp - 2]                                  ; Restore old DS segment
  mov sp, bp                                        ; Restore stack frame
  pop bp                                            ;
  ret

.err:
  xor ax, ax
  jmp .end

%endif