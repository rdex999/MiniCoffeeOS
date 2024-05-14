;
; ---------- [ SYSTEM COMMANDS ] ----------
;

%ifndef SYSTEM_ASM
%define SYSTEM_ASM

%include "kernel/system/parseCmd.asm"

; Comapre two commands, and just if equal
; PARAMETERS
;   - 0) The lable to just to
;   - 1) The entered command
;   - 2) The command to compare to
%macro CMDCMP_JUMP 3

  %if %2 != di
    mov di, %2
  %endif

  %if %3 != si
    mov si, %3
  %endif

  call cmdcmp
  test ax, ax
  jz %1

%endmacro


; Note: the name "system" is from the C function, thats running a system command

; Execute a system command
; PARAMETERS
;   - 0) ES:DI    => The command string to execute (destructive)
; RETURNS
;   - 0) AX       => The commands error code
system:
  push bp                                   ; Save stack frame
  mov bp, sp                                ;
  sub sp, 9                                 ; Allocate space for local stuff

  mov [bp - 2], ds                          ; Save used segments
  mov [bp - 4], es                          ;
  mov [bp - 6], di                          ;

  mov bx, KERNEL_SEGMENT                    ; DS will be used as the kernels segment
  mov ds, bx                                ;

  mov cx, 0FFFFh
  mov al, ' '
  cld
  repe scasb

  dec di

  ; The way this command works is that most commands are executables in the /bin folder, 
  ; but some simple commands like "clear" and "help" are just built in

  ; Check for built it
  CMDCMP_JUMP .help, di, cmdHelp
  CMDCMP_JUMP .clear, di, cmdClear

  ; If its not a build in, parse the first part of the command 
  ; into a binary in the bin folder ("move" => "/bin/move")
  ; Then parse the arguments, and save an array of pointers for it on this functions stack
  call countCmdArgBytes                     ; Get the length of the first argument
  test ax, ax                               ; Check if its zero
  jz .retZero                               ; If it is, just return 0

  cmp ax, 10
  jae .errNotFound

  add ax, 5 + 1                             ; If its not zero, increase the amount by 5+1 because we might add "/bin/" to the name.
  sub sp, ax                                ; Allocate space for formatted command
  mov [bp - 8], sp                          ; Save allocated buffer

  mov bx, es                                ; Set DS:SI point to the command string
  mov ds, bx                                ; Set segment
  mov si, di                                ; Set offset

  mov bx, ss                                ; Set ES:DI to the buffer we just allocated
  mov es, bx                                ; Set segment
  mov di, sp                                ; Set offset
  push si                                   ; Save the offset of the command string pointer
  call parseExecArg                         ; Parse the fist argument into an executables path

  mov es, [bp - 4]                          ; Restore command string segment
  pop di                                    ; Restore command string offset

  call countCmdArgs                         ; Count the amount of arguments in the command
  mov [bp - 9], al                          ; Store it
  shl ax, 1                                 ; Multiply it by 2, because were creating an array of near pointers (each pointer is 2 bytes)
  sub sp, ax                                ; Allocate space for the array

  mov bx, es                                ; Set DS:SI point to the command string
  mov ds, bx                                ; Set segment
  mov si, di                                ; Set offset
  
  mov bx, ss                                ; Set ES:DI point to the path buffer on the stack
  mov es, bx                                ; Set segment
  mov di, sp                                ; Set offset
  call parseCmdArgs                         ; Parse the command, null terminate arguments and create an array of pointers with the arguments

  mov bx, ss                                ; Set ES:DI to the executables path
  mov es, bx                                ; Set segment
  mov di, [bp - 8]                          ; Set offset

  mov ds, bx                                ; Set DS:SI point to the array of arguments
  mov si, sp                                ; Set offset

  mov dl, [bp - 9]                          ; Set DL to the amount of arguments in the array
  xor dh, dh                                ; Zero out high 8 bits

  mov cl, PROCESS_DESC_F_ALIVE              ; Set the alive flag so the process will run
  mov bx, [bp - 2]                          ; The segment of each argument string
  call createProcess                        ; Create the process and get a handle to it in AX
  test bx, bx                               ; Check error code
  jz .createdProcess                        ; If there was no error, skip printing an error message

.errNotFound:
  mov bx, KERNEL_SEGMENT                    ; Make DS:SI point to the "command not found" error message
  mov ds, bx                                ;
  lea si, errCmdNotFound                    ;
  mov di, ds:[trmColor]                     ; Get the current terminal color
  call printStr                             ; Print the error message
  mov ax, ERR_FILE_NOT_FOUND 
  jmp .end                                  ; Return with it

.createdProcess:
  xor ah, ah
  dec ax                                    ; Decrement the PID by 1, to get processes index
  mov bx, PROCESS_DESC_SIZEOF               ; We want to multiply by the size of a process descriptor
  mul bx                                    ; Get the offset into the processes array for the new process

  mov bx, KERNEL_SEGMENT                    ; Set DS to the kernels segment so we can access the processes array
  mov ds, bx                                ;
  
  lea si, processes                         ; Get a pointer to the processes array
  add si, ax                                ; Offset it so it points to the new process
.waitProcessExit:
  hlt                                       ; Halt so the CPU wont explode
  test byte ds:[si + PROCESS_DESC_FLAGS8], PROCESS_DESC_F_ALIVE   ; Check if the process is still alive
  jnz .waitProcessExit                                            ; If it is alive, continue waiting

  mov al, ds:[si + PROCESS_DESC_EXIT_CODE8]
  jmp .end                                                        ; When the processes has died, return

.help:
  mov di, ds:[trmColor]                     ; Get the terminals current color
  lea si, helpMsg                           ; Get a pointer to the help message
  call printStr                             ; Print the help message

  xor ax, ax                                ; Exit with 0
  jmp .end                                  ; Return

.clear:
  call clear                                ; Clear the screen
.retZero:
  xor ax, ax                                ; Return 0

.end:
  mov bx, KERNEL_SEGMENT
  mov ds, bx
  mov ds:[cmdLastExitCode], al

  mov ds, [bp - 2]                          ; Restore used segments
  mov es, [bp - 4]                          ;
  mov sp, bp                                ; Restore stack frame 
  pop bp                                    ;
  ret


; compares two commands (strings)
; basicli compares two strings but stops on a space
; PARAMS
;   - 0) ES:DI    => The entered command
;   - 1) DS:SI    => the command to compare to
; RETURNS
;   - 0) In AX, 0 if the commands are equal, 1 if not equal
cmdcmp:
  push di                                   ; Save entered command
  cld                                       ; Clear direction flag so LODSB and SCASB will increment SI and DI respectively
  mov cx, 0FFFFh                            ; Maximum amount of bytes its possible to copy
  sub cx, di                                ; Subtract the entered commands offset from it

.cmpLoop:
  lodsb                                     ; Get the current character in the string were comparing to

  test al, al                               ; Check if its the end of the string
  jnz .notNull                              ; If not, compare letters normaly

  scasb                                     ; Check if its the end of the entered command too
  je .equal                                 ; If it is, then they are equal

  ; If its not the end of the source command, check if the letter in the source command is ' ' (which means they are equal)
  cmp byte es:[di - 1], ' '                 ; Check if the letter in the source command is a space ' '
  je .equal                                 ; If it is, then they are equal

  jmp .notEqual                             ; If its not a space, then they are not equal

.notNull:
  scasb                                     ; Compare the character from the command to the source command
  je .cmpLoop                               ; As long as its equal, continue comparing

.notEqual:
  mov ax, 1                                 ; If not equal, return 1
  jmp .end

.equal:
  xor ax, ax                                ; If equal, return 0
.end:
  pop di                                    ; Restore source command pointer offset
  ret

%endif