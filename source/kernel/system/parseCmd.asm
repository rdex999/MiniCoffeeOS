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
parseExecCmd:
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


; Get the length of the current argument
; Note: parameters stay unchanged
; PARAMETERS
;   - 0) ES:DI  => The command string
;  RETURNS
;   - 0) AX     => The length of the current argument
countCmdArgBytes:
  push ds                         ; Save DS segment because changing it

  mov bx, es                      ; Set DS:SI to the command string, because LODSB is using DS:SI
  mov ds, bx                      ; Set segment
  mov si, di                      ; Set offset

  cld                             ; Clear direction flag so LODSB will increment SI each time
.cntLoop:
  lodsb                           ; Get the next character from the command string

  test al, al                     ; Check if its null
  jz .retCnt                      ; If it is, return the legnth

  cmp al, ' '                     ; Check if the character is a space
  je .retCnt                      ; If it is, return the legnth

  jmp .cntLoop                    ; Continue counting characters

.retCnt:
  mov ax, si                      ; Get the current character location in AX
  sub ax, di                      ; Subtract the location of the first character from it
  dec ax                          ; Decrement by 1 because DS:SI was pointing to the character after the last one

.end:
  pop ds                          ; Restore DS segment
  ret


%endif