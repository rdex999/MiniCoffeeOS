;
; ---------- [ PARSE A COMMAND ] ---------
;

%ifndef PARSE_CMD_ASM
%define PARSE_CMD_ASM

; Parse a command into an executable path. For example:
; cmd = "move"
; parsed_cmd = "/bin/move"
; PARAMETERS
;   - 0) ES:DI  => A buffer to store the parsed command in
;   - 1) DS:SI  => The command to parse
; Doesnt return anything
parseExecArg:
  push bp                         ; Save stack frame
  mov bp, sp                      ;
  sub sp, 8                       ; Allocate space for local shit

  mov [bp - 2], es                ; Save parameters
  mov [bp - 4], di                ; Buffer pointer
  mov [bp - 6], ds                ; Command pointer 
  mov [bp - 8], si                ;

  cmp byte ds:[si], '/'           ; Check if the first character of the command is '/', in which case we dont need to parse it
  jne .notFromRootDir             ; If its not a '/' then dont copy the command

  mov bx, ds                      ; Get command pointer in ES:DI
  mov es, bx                      ; Set segment
  mov di, si                      ; Set offset
  call countCmdArgBytes           ; Get the length of the argument (the first part of the command)

  mov bx, es                      ; Get command pointer in DS:SI
  mov ds, bx                      ; Set segment
  mov si, di                      ; Set offset

  mov es, [bp - 2]                ; Get a pointer to the given buffer (the parameter)
  mov di, [bp - 4]                ; Get offset

  mov dx, ax                      ; Set DX to the length of the argument    // Amount of bytes to copy in memcpy
  push ax                         ; Save the amount of bytes were copying
  call memcpy                     ; Copy the argument into the buffer
  pop ax                          ; Restore amount of bytes copied

  add di, ax                      ; Offset the buffer so it points to the place after the last character
  mov byte es:[di], 0             ; Null terminate the string

  jmp .end                        ; Return

.notFromRootDir:
  mov bx, KERNEL_SEGMENT          ; Get a pointer to the "/bin/" in the shells executable path
  mov ds, bx                      ; Get segment
  lea si, shellExec               ; Get offset
  
  mov es, [bp - 2]                ; Get a pointer to the given buffer
  mov di, [bp - 4]                ; Offset
  mov dx, 5                       ; Amount of bytes to copy, strlen("/bin/") == 5
  call memcpy                     ; Copy the "/bin/" to the buffer

  mov es, [bp - 6]                ; Get a pointer to the command string
  mov di, [bp - 8]                ; Offset
  call countCmdArgBytes           ; Get the length of the first argument (the first part of the command)

  mov es, [bp - 2]                ; Get a pointer to the given buffer
  mov di, [bp - 4]                ; Get offset
  add di, 5                       ; Offset the buffer so it pointes at the character after the "/bin/"

  mov ds, [bp - 6]                ; Get a pointer to the command string
  mov si, [bp - 8]                ; Get offset

  mov dx, ax                      ; Set the amount of bytes to copy to the length of the argument
  push ax                         ; Save the amount of bytes were gonna copy
  call memcpy                     ; Copy the first part of the command into the buffer, after the "/bin/"
  pop ax                          ; Restore amount of bytes copied

  add di, ax                      ; Offset the buffer so it pointes right after the last character
  mov byte es:[di], 0             ; Null terminate the string

.end:
  mov sp, bp                      ; Restore stack frame
  pop bp                          ;
  ret


; Parse the whole command string, create an array of pointers for each argument and null terminate the arguments
; PARAMETERS
;   - 0) ES:DI  => The buffer to store the argument array in
;   - 1) DS:SI  => The command string
; Doesnt return anything
parseCmdArgs:
  ret

; Get the length of the current argument
; Note: parameters stay unchanged
; PARAMETERS
;   - 0) ES:DI  => The command string
;  RETURNS
;   - 0) AX     => The length of the current argument
;   - 1) DS:SI  => A pointer to the next argument
countCmdArgBytes:
  mov bx, es                      ; Set DS:SI to the command string, because LODSB is using DS:SI
  mov ds, bx                      ; Set segment
  mov si, di                      ; Set offset

  ; We want to skip the first spaces
  mov bx, di                      ; Save DI in BX because changing it
  mov cx, 0FFFFh                  ; Set maximum amount of bytes to check
  mov al, ' '                     ; Character to check for
  repe scasb                      ; Skip all spaces

  dec di                          ; Decrement string pointer, because it points to the character after the character thats not a space
  mov si, di                      ; Reset DS:SI to the first character of the argument
  mov di, bx                      ; Restore DI

  xor cx, cx                      ; Zero out bytes count

  cld                             ; Clear direction flag so LODSB will increment SI each time
.cntLoop:
  lodsb                           ; Get the next character from the command string

  test al, al                     ; Check if its null
  jnz .notNull                    ; If it is, return the legnth

  dec si                          ; If null, decrement string pointer so it points to the null byte
  jmp .retCnt                     ; Return the amount of bytes

.notNull:
  cmp al, ' '                     ; Check if the character is a space
  je .isSpace                     ; If it is, return the legnth

  inc cx                          ; If its not null nor a space, increase the bytes count

  jmp .cntLoop                    ; Continue counting characters

.isSpace:
  push cx                         ; Save current byte count
  mov bx, di                      ; Save DI in BX

  mov di, si                      ; Get string pointer in ES:DI (ES already set)
  mov cx, 0FFFFh                  ; Set the amount of bytes to check to the maximum amount we can

  ; Skip all of the spaces, when getting out of this instruction, 
  ; ES:DI will point to the character after the character thats not a space
  repe scasb                      ; Skip all spaces

  mov si, di                      ; Get a pointer to the next argument
  dec si                          ; Decrement by 1 so DS:SI points to the first character of the next argument

  mov di, bx                      ; Restore DI
  pop cx                          ; Restore byte count

.retCnt:
  mov ax, cx                      ; Return the amount of bytes in the argument

.end:
  ret


; Count the amount of arguments in a command string
; Note: parameters stay unchanged
; PARAMETERS
;   - 0) ES:DI  => The command string
; RETURNS
;   - 0) AX     => The amount of arguments in the command
countCmdArgs:
  push di                         ; Save DI because changing it
  push ds                         ; Save used segment

  xor ax, ax                      ; Zero out arguments counter

.cntLoop:
  push ax                         ; Save arguments count
  call countCmdArgBytes           ; Get a pointer to the next argument
  test ax, ax                     ; Check if the length of the current one is 0
  pop ax                          ; Restore arguments count
  jz .end                         ; If the length was zero, return

  mov bx, ds                      ; Set ES:DI to the next argument
  mov es, bx                      ; Set segment
  mov di, si                      ; Set offset

  inc ax                          ; Increase arguments count

  cmp byte es:[di], 0             ; Check if its the end of the command
  jne .cntLoop                    ; As long as its not the end, continue counting

.end:
  pop ds                          ; Restore used segment
  pop di                          ; Restore offset
  ret

%endif