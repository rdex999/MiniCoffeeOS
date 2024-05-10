;
; ---------- [ SYSTEM COMMANDS ] ----------
;

%ifndef SYSTEM_ASM
%define SYSTEM_ASM

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
;   - 0) ES:DI    => The command string to execute
; RETURNS
;   - 0) AX       => The commands error code
system:
  push bp
  mov bp, sp
  sub sp, 2

  mov [bp - 2], ds

  mov bx, KERNEL_SEGMENT
  mov ds, bx

  CMDCMP_JUMP .help, di, cmdHelp
  CMDCMP_JUMP .clear, di, cmdClear

  jmp .end

.help:
  mov di, ds:[trmColor]
  lea si, helpMsg
  call printStr

  xor ax, ax
  jmp .end

.clear:
  call clear
  xor ax, ax

.end:
  mov ds, [bp - 2] 
  mov sp, bp
  pop bp
  ret


; compares two commands (strings)
; basicli compares two strings but stops on a space
; PARAMS
;   - 0) ES:DI    => The entered command
;   - 1) DS:SI    => the command to compare to
; RETURNS
;   - 0) In AX, 0 if the commands are equal, 1 if not equal
cmdcmp:
  push di
  cld
  mov cx, 0FFFFh
  sub cx, di

.cmpLoop:
  lodsb

  test al, al
  jnz .notNull

  scasb
  je .equal

  cmp byte es:[di - 1], ' '
  je .equal

  jmp .notEqual

.notNull:
  scasb
  je .cmpLoop

.notEqual:
  mov ax, 1
  jmp .end

.equal:
  xor ax, ax
.end:
  pop di
  ret





%endif