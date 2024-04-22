;
; ---------- [ OPEN A FILE FOR A REQUESTED MODE ] ----------
;

%ifndef FOPEN_ASM
%define FOPEN_ASM

; Open a file from the filesystem in a specific mode.
; FILE ACCESS
;   0 Read ("r")
;   1 Write ("w")
;   2 Append ("a")
;   3 Read Write, must exist ("r+")
;   4 Read Write ("w+")
;   5 Append Read ("a+")
; PARAMETERS
;   - 0) ES:DI    => The path to the file, doesnt have to be formatted. Null terminated string.
;   - 1) SI       => Access for the file, low 8 bits only
; RETURNS
;   - 0) In AX, the file handle. A non-zero value on success. (0 on failure) 
;       // Note for me: returns the INDEX into openFiles (index+1)
fopen:
  push bp                                         ; Save stack frame
  mov bp, sp                                      ;
  sub sp, 5                                       ; Allocate memory on the stack

  mov [bp - 2], es                                ; Save used segments
  mov [bp - 4], ds                                ;
  mov ax, si                                      ; Save low 8 bits of the requested file access
  mov [bp - 6], al                                ;

  mov bx, es                                      ; Set DS:SI = ES:DI (the pointers)                              
  mov ds, bx                                      ; Set DS = ES
  mov si, di                                      ; Set SI = DI. Doing this because getFileEntry wants DS:SI to be the file path

  mov bx, KERNEL_SEGMENT                          ; Set ES to kernel segment 
  mov es, bx                                      ; so we can access the openFiles array

  ; Search the openFiles array for an unused slot for the file
  xor cx, cx 
  lea di, [openFiles]                             ; Get a pointer to the start of the openFiles array
.searchEmptySlot:
  cmp word es:[di + FILE_OPEN_ENTRY256 + 26], 0   ; Check if the files first cluster number is zero.
  je .foundEmpty                                  ; If zero then we found an empty file slot

  add di, FILE_OPEN_SIZEOF                        ; If the slot is not empty, increase the openFiles pointer to point to the next slot

  inc cx                                          ; Increase slots counter
  cmp cx, FILE_OPEN_LEN                           ; Check if there are more slots to check
  jb .searchEmptySlot                             ; If there is, then continue searching

  ; If there is not unused slot then return an error for it
  xor ax, ax                                      ; Return null on error
  jmp .end                                        ; Return

.foundEmpty:
  push cx                                         ; Save slot index
  push di                                         ; Save openFiles slot pointer
  add di, FILE_OPEN_ENTRY256                      ; Get a pointer to the start of the file descriptor in openFiles
  call getFileEntry                               ; Store the files entry in ES:DI, the 32 byte (256 bits)
  pop di                                          ; Restore openFiles slot pointer
  pop cx                                          ; Restore slot index
  test ax, ax                                     ; Check getFileEntry error code
  jz .setAccess                                   ; If no error, then set the files access and return the file handle

  xor ax, ax                                      ; If getFileEntry has failed, then return 0 (indicating an error)
  jmp .end                                        ; Return

.setAccess:
  mov bl, [bp - 5]                                ; Get requested file access
  mov es:[di + FILE_OPEN_ACCESS8], bl             ; Set files access
  mov ax, cx                                      ; Get the files slot index
  inc ax                                          ; Increase by 1 so we dont return 0 for a valid index (0 indicates error)

.end:
  mov es, [bp - 2]                                ; Restore used segments
  mov ds, [bp - 4]                                ;
  mov sp, bp                                      ; Restore stack frame
  pop bp                                          ;
  ret

%endif