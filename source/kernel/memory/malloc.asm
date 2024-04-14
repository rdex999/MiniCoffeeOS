;
; ---------- [ A FUNCTION TO DYNAMICALLY ALLOCATE MEMORY ] ----------
;

%ifndef MALLOC_ASM
%define MALLOC_ASM



; Dynamically allocate a chunk of memory
; PARAMS
;   - 0) DI   => Size of memory chunk, in bytes
; RETURNS
;   - ES:DI   => A pointer to the memory chunk, while the segment is in ES and the offset in AX
;                The function may return a null pointer (that is, ES = 0 && AX = 0) if couldnt allocate memory.
malloc:
  push bp
  mov bp, sp

  push es
  push gs

  mov bx, KERNEL_SEGMENT
  mov gs, bx
  mov es, bx

  mov di, kernelEnd
  call getNextSegOff

malloc_end:
  pop gs
  pop es
  mov sp, bp
  pop bp
  ret

%endif