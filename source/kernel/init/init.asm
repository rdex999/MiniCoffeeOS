;
;   ---------- [ FUNCTIONS THAT RUN ON KERNEL START ] ----------
;

%ifndef INIT_ASM
%define INIT_ASM

; Copies the BPB and the EBPB from BIOS.
; PARAMS
;   0) lable  => where to copy to
%macro COPY_BPB 1

  pusha
  xor ax, ax
  mov ds, ax
  mov ax, KERNEL_SEGMENT
  mov es, ax

  lea di, %1
  mov si, 7C00h
  mov cx, 62/2        ; BPB + EBPB = 62 // divibe by 2 because increasing pointers by 2
  cld
  repe movsw 
  mov ax, KERNEL_SEGMENT
  mov ds, ax 
  popa

%endmacro

; Sets an interrupt in the IVT. When using this macro ES must be set to 0.
; PARAMS
;   - 0) Interrupt number. (Not the index in the IVT) Must be a constant.
;   - 1) Segment for interrupt handler
;   - 2) Offset for interrupt handler
%macro SET_IVT 3

  mov word es:[%1 * 4], %3
  mov word es:[%1 * 4 + 2], %2

%endmacro

; Adds interrupt handler to the IVT
%macro IVT_INIT 0

  cli
  push es
  xor bx, bx
  mov es, bx
  
  SET_IVT 0, cs, ISR_divZero


  pop es
  sti

%endmacro


; When the kernel first starts up, need to initialize some things. (Like cpying the BPB from the bootlaoder)
; I made this macro here because it will only be included once.
%macro INIT_KERNEL 0

  ; Copy the BPB and the EBPB from the bootloader 
  COPY_BPB bpbStart
  mov sp, 0FFFFh                    ; Make stack larger
  mov byte [currentPath], '/'

  IVT_INIT


%endmacro

%endif