;
; ---------- [ HANDLE KERNEL INTERRUPTS ] ---------
;

%ifndef KERNEL_INT_ASM
%define KERNEL_INT_ASM

%include "kernel/isr/kernelInts/putchar.asm"
%include "kernel/isr/kernelInts/putcharLoc.asm"
%include "kernel/isr/kernelInts/puts.asm"
%include "kernel/isr/kernelInts/putsLoc.asm"
%include "kernel/isr/kernelInts/printf.asm"
%include "kernel/isr/kernelInts/waitChar.asm"

; Interrupt number in AX, and other parameters are as documented in "source/kernel/macros/interrupts.asm"
ISR_kernelInt:
  push bx                             ; Save general purpos registers (PUSHA & POPA sucks)
  push cx                             ; 
  push dx                             ;
  push si                             ;
  push di                             ;

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

ISR_kernelInt_end:
  pop di
  pop si
  pop dx
  pop cx
  pop bx
  iret

%endif