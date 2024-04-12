;
; ---------- [ BASIC COMMANDS ] ----------
;

%ifndef BASICCOMMANDS_ASM
%define BASICCOMMANDS_ASM

%include "kernel/trmCommands/clear.asm"

; compares two commands (strings)
; basicli compares two strings but stops on a space
; PARAMS
; 0) const char* (DI) => string (the entered command)
; 1) const char* (SI) => string (the target command)
; RETURNS
; 0 if no difference was found, and 1 if there was a difference
cmdcmp:
  cmp byte [di], ' '
  je cmdcmp_spaceFirst

  mov al, [di]
  cmp al, [si]
  jne cmdcmp_notEqual 

  inc di
  inc si

  test al, al
  jnz cmdcmp
  
cmdcmp_endTrue:
  xor ax, ax
  ret

cmdcmp_notEqual:
  mov ax, 1
  ret

cmdcmp_spaceFirst:
  cmp byte [si], 0
  je cmdcmp_endTrue
  mov ax, 1
  ret



kernel_printHelp:
  push es
  push ds
  mov bx, KERNEL_SEGMENT
  mov es, bx
  mov ds, bx

  mov di, es:[trmColor] 
  lea si, [helpMsg]
  call printStr

  pop ds
  pop es
  jmp kernel_readCommandsLoop

kernel_clear:
  call clear
  jmp kernel_readCommandsLoop

%endif