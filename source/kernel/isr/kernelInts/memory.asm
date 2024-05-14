;
; ---------- [ MEMORY RELATED INTERRUPTS ] ----------
;

%ifndef INT_MEMORY_ASM
%define INT_MEMORY_ASM

; Copies a chunk of memory from one location to another.
; PARAMS
;   - 0) ES:DI    => Memory to copy to, the destination.
;   - 1) DS:SI    => Memory to copy data from, the source.
;   - 2) DX       => The amount of memory to copy, in bytes.
; RETURNS
;   - ES:DI       => The original destination pointer
ISR_memcpy:
  call memcpy
  mov ax, di
  jmp ISR_kernelInt_end_restBX

; Get the length of a null-terminated string.
; PARAMETERS
;   - 0) ES:DI    => The string, null terminated
; RETURNS
;   - 0) AX       => The length of the string, in bytes.
ISR_strlen:
  call strlen
  jmp ISR_kernelInt_end_restBX

%endif