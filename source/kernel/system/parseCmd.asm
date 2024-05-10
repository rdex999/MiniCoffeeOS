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

  ;;; Fix soon
  call strcpy
  jmp .end

.notFromRootDir:
  mov bx, KERNEL_SEGMENT          ; Get a pointer to the "/bin/" in the shells executable path
  mov ds, bx                      ; Get segment
  lea si, shellExec               ; Get offset
  
  mov es, [bp - 2]                ; Get a pointer to the given buffer
  mov di, [bp - 4]                ; Offset
  mov dx, 5                       ; Amount of bytes to copy, strlen("/bin/") == 5
  call memcpy                     ; Copy the "/bin/" to the buffer

  add di, 5                       ; Offset the buffer pointer, so it pointes to the first character after the "/bin/"

  ;;; Fix soon
  mov ds, [bp - 6]
  mov si, [bp - 8]
  call strcpy

.end:
  mov sp, bp                      ; Restore stack frame
  pop bp                          ;
  ret


%endif