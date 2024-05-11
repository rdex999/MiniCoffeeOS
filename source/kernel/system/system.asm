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
  sub sp, 6                                 ; Allocate space for local stuff

  mov [bp - 2], ds                          ; Save used segments
  mov [bp - 4], es                          ;
  mov [bp - 6], di                          ;

  mov bx, KERNEL_SEGMENT                    ; DS will be used as the kernels segment
  mov ds, bx                                ;

  ; The way this command works is that most commands are executables in the /bin folder, 
  ; but some simple commands like "clear" and "help" are just built in

  ; Check for built it
  CMDCMP_JUMP .help, di, cmdHelp
  CMDCMP_JUMP .clear, di, cmdClear

  ; If its not a build in, parse the first part of the command 
  ; into a binary in the bin folder ("move" => "/bin/move")
  ; Then parse the arguments, and save an array of pointers for it on this functions stack
  call countCmdArgBytes
  add ax, 5 + 1
  sub sp, ax

  push ax
  push di

  call countCmdArgs

  mov bx, KERNEL_SEGMENT
  mov ds, bx

  PRINTF_M `args count: %u\n`, ax


  pop di
  pop ax

  shl ax, 1
  sub sp, ax

  mov bx, es                                ; Set DS:SI point to the command string
  mov ds, bx                                ; Set segment
  mov si, di                                ; Set offset
  
  mov bx, ss                                ; Set ES:DI point to the path buffer on the stack
  mov es, bx                                ; Set segment
  mov di, sp                                ; Set offset
  ; call parseCmdArgs



  jmp .end

.help:
  mov di, ds:[trmColor]                     ; Get the terminals current color
  lea si, helpMsg                           ; Get a pointer to the help message
  call printStr                             ; Print the help message

  xor ax, ax                                ; Exit with 0
  jmp .end                                  ; Return

.clear:
  call clear                                ; Clear the screen
  xor ax, ax                                ; Return 0

.end:
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