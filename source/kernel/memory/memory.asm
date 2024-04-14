;
; ---------- [ FUNCTIONS FOR MANIPULATING/ALLOCATING MEMORY ] ----------
;

%ifndef MEMORY_ASM
%define MEMORY_ASM

%include "kernel/memory/malloc.asm"

; Converts a segment:offset pointer into the next segment:offset.
; For example you have 7E0:FFFF the function will return 17DF:000F
; The function uses the formula: 
; newSeg = seg + (offset >> 4)
; newOffset = offset & 0Fh
; PARAMS
;   - 0) ES:DI    => The current segment:offset pair
; RETURNS
;   - ES:DI   => The new segment offset pair
getNextSegOff:
  mov ax, di
  shr ax, 4
  mov bx, es
  add bx, ax
  mov es, bx

  and di, 0Fh
  ret

%endif