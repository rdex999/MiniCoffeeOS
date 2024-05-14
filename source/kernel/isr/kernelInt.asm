;
; ---------- [ HANDLE KERNEL INTERRUPTS ] ---------
;

%ifndef KERNEL_INT_ASM
%define KERNEL_INT_ASM

%define KERNEL_INT_STACK (2 * 6)

%include "kernel/isr/kernelInts/putchar.asm"
%include "kernel/isr/kernelInts/putcharLoc.asm"
%include "kernel/isr/kernelInts/puts.asm"
%include "kernel/isr/kernelInts/putsLoc.asm"
%include "kernel/isr/kernelInts/printf.asm"
%include "kernel/isr/kernelInts/waitChar.asm"
%include "kernel/isr/kernelInts/waitInput.asm"
%include "kernel/isr/kernelInts/cursor.asm"
%include "kernel/isr/kernelInts/terminal.asm"
%include "kernel/isr/kernelInts/files.asm"
%include "kernel/isr/kernelInts/time.asm"
%include "kernel/isr/kernelInts/process.asm"
%include "kernel/isr/kernelInts/user.asm"
%include "kernel/isr/kernelInts/memory.asm"

; Interrupt number in AX, and other parameters are as documented in "source/kernel/macros/interrupts.asm"
ISR_kernelInt:
  push bp
  mov bp, sp 
  sub sp, KERNEL_INT_STACK

  mov [bp - 2], ax
  mov [bp - 4], bx
  mov [bp - 6], cx
  mov [bp - 8], dx
  mov [bp - 10], si
  mov [bp - 12], di
  
  ; A switch-case for the interrupt number
  cmp ax, INT_N_PUTCHAR
  je ISR_putchar

  cmp ax, INT_N_PUTCHAR_LOC
  je ISR_putcharLoc

  cmp ax, INT_N_PUTS
  je ISR_puts

  cmp ax, INT_N_PUTS_LOC
  je ISR_putsLoc

  cmp ax, INT_N_PRINTF
  je ISR_printf

  cmp ax, INT_N_WAIT_CHAR
  je ISR_waitChar

  cmp ax, INT_N_WAIT_CHAR_NO_ECHO
  je ISR_waitCharNoEcho

  cmp ax, INT_N_WAIT_INPUT
  je ISR_waitInput

  cmp ax, INT_N_GET_CURSOR_LOCATION
  je ISR_getCursorLocation

  cmp ax, INT_N_SET_CURSOR_LOCATION
  je ISR_setCursorLocation

  cmp ax, INT_N_TRM_CLEAR
  je ISR_trmClear

  cmp ax, INT_N_TRM_GET_COLOR
  je ISR_trmGetColor

  cmp ax, INT_N_TRM_SET_COLOR
  je ISR_trmSetColor

  cmp ax, INT_N_FOPEN
  je ISR_fopen

  cmp ax, INT_N_FCLOSE
  je ISR_fclose

  cmp ax, INT_N_FREAD
  je ISR_fread

  cmp ax, INT_N_FWRITE
  je ISR_fwrite

  cmp ax, INT_N_REMOVE
  je ISR_remove

  cmp ax, INT_N_GET_LOW_TIME
  je ISR_getLowTime

  cmp ax, INT_N_GET_SYS_TIME
  je ISR_getSysTime

  cmp ax, INT_N_GET_SYS_DATE
  je ISR_getSysDate

  cmp ax, INT_N_SLEEP
  je ISR_sleep

  cmp ax, INT_N_EXIT
  je ISR_exit

  cmp ax, INT_N_GET_USER_PATH
  je ISR_getUserPath

  cmp ax, INT_N_SYSTEM
  je ISR_system

  cmp ax, INT_N_GET_EXIT_CODE
  je ISR_getExitCode

  cmp ax, INT_N_MEMCPY
  je ISR_memcpy

  cmp ax, INT_N_STRLEN
  je ISR_strlen

ISR_kernelInt_end:
; *NOTE: "rest" == restore
ISR_kernelInt_restAX:
  mov ax, [bp - 2]
ISR_kernelInt_end_restBX:
  mov bx, [bp - 4]
ISR_kernelInt_end_restCX:
  mov cx, [bp - 6]
ISR_kernelInt_end_restDX:
  mov dx, [bp - 8]
ISR_kernelInt_end_restSI:
  mov si, [bp - 10]
ISR_kernelInt_end_restDI:
  mov di, [bp - 12]
ISR_kernelInt_end_dontRest:
  mov sp, bp
  pop bp 
  iret                                ; Return from the interrupt

%endif