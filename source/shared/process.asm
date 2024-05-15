%ifndef SHARED_PROCESS_ASM
%define SHARED_PROCESS_ASM

; Each process is placed in a different segment, at offset 200h. The stack pointer is also initialized at 200h
; When first executing the process, AX:BX will point to an array of arguments, 
; while each argument is a near pointer (2 bytes, just an offset) all arguments have the same segment, which is placed in the DX register
; The amount of arguments is stored in the CX register

%define PROCESS_LOAD_OFFSET 100h

%endif