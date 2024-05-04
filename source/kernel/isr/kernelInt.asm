;
; ---------- [ HANDLE KERNEL INTERRUPTS ] ---------
;

%ifndef KERNEL_INT_ASM
%define KERNEL_INT_ASM

%include "kernel/isr/kernelInts/putchar.asm"

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


ISR_kernelInt_end:
  pop di
  pop si
  pop dx
  pop cx
  pop bx
  iret

%endif