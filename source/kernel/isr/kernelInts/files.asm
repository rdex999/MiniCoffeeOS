;
; ---------- [ FILE MANIPULATION INTERRUPTS ] ----------
;

%ifndef FILE_ASM
%define FILE_ASM

; Open a file from the filesystem in a specific mode.
; FILE ACCESS
;   0 Read ("r")                      - Open the file for reading
;   1 Write ("w")                     - Create file, delete content if exists
;   2 Append ("a")                    - Open for appending to the end of the file, create if doesnt exist
;   3 Read write ("r+")               - Open for both reading and writing, file must exist
;   4 Write read ("w+")               - Create for writing and reading, delete content if the file exists
;   5 Append read ("a+")              - Open file for appending and reading, create file if doesnt exist
; PARAMETERS
;   - 0) ES:DI    => The path to the file, doesnt have to be formatted. Null terminated string.
;   - 1) SI       => Access for the file, low 8 bits only
; RETURNS
;   - 0) In AX, the file handle. A non-zero value on success. (0 on failure)
ISR_fopen:
  call fopen                    ; Open the file, while the filename is in ES:DI and the requested access is in SI
  jmp ISR_kernelInt_end_restBX  ; Return with the handle/error code in AX


ISR_fclose:
  call fclose
  jmp ISR_kernelInt_end_restBX


; Read from an open file at the current read position
; **Parameters are a bit different from the C fread.
; PARAMETERS
;   - 0) ES:DI  => Buffer to read data into
;   - 1) SI     => Number of bytes to read
;   - 2) DX     => File handle
; RETURNS
;   - 0) In AX, the amount of bytes read, can be less then the parameter if an error occurred.
ISR_fread:
  call fread
  jmp ISR_kernelInt_end_restBX


; Write to the current position in a file.
; PARAMS
;   - 0) ES:DI  => The buffer of data to be written to the file
;   - 1) SI     => The amount of bytes to write to the file
;   - 2) DX     => A handle to the file
; RETURNS
;   - 0) In AX, the amount of bytes written. Can be less than the requested amount if an error occurs
ISR_fwrite:
  call fwrite
  jmp ISR_kernelInt_end_restBX


; Delete a file from the filesystem
; PARAMETERS
;   - 0) ES:DI    => Path to the file
; RETURNS
;   - 0) AX       => Error code
ISR_remove:
  call remove
  jmp ISR_kernelInt_end_restBX


; Create a directory
; PARAMETERS
;   - 0) ES:DI    => New directory path
; RETURNS
;   - 0) AX       => Error code, 0 on s
ISR_mkdir:
  push es
  push ds
  mov bx, es
  mov ds, bx
  mov si, di

  xor bx, bx
  mov es, bx
  xor di, di

  mov dl, FAT_F_DIRECTORY
  call createFile
  pop ds
  pop es
  jmp ISR_kernelInt_end_restBX

%endif