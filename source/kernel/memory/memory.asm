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

; Initialize the heap
; Basicaly initialize the heapChunks array (set all chunks to free)
heapInit:
  push bp
  mov bp, sp
  sub sp, 4

  push es
  push gs 
  mov bx, KERNEL_SEGMENT
  mov es, bx
  mov gs, bx                          ; GS will be used as the kernel segment

  lea si, [heapChunks]
  lea di, [kernelEnd]

  push si 
  call getNextSegOff
  pop si

  mov ax, 0FFFFh
  sub ax, di

heapInit_setFreeLoop:
  mov word gs:[si + HEAP_CHUNK_SEG], es
  mov word gs:[si + HEAP_CHUNK_OFF], di
  mov word gs:[si + HEAP_CHUNK_SIZE], ax
  add si, HEAP_SIZEOF_HCHUNK
  
  mov [bp - 2], es
  mov [bp - 4], di
  
  add di, ax
  push si
  call getNextSegOff
  pop si

  mov bx, es
  mov ax, 0FFFFh
  sub ax, di
  mov cx, ax
  shr cx, 4
  add bx, cx
  cmp bx, HEAP_END_SEG
  jb heapInit_setFreeLoop

  mov bx, [bp - 2]
  mov cx, [bp - 4]
  mov ax, 0FFFFh
  sub ax, cx
  shr ax, 4
  add bx, ax
  mov ax, HEAP_END_SEG
  sub ax, bx
  js heapInit_end

  shl ax, 4
  dec ax
  jmp heapInit_setFreeLoop

heapInit_end:
  pop gs
  pop es

  mov sp, bp
  pop bp
  ret


; Print the heapChunks array
;;;;;;; THIS IS A DEBUG FUNCTION
heapPrintHChunks:
  push es
  mov bx, KERNEL_SEGMENT
  mov es, bx

  mov cx, HEAP_FREE_CHUNKS
  lea si, [heapChunks]
heapPrintHChunks_loop:
  push cx

  mov ax, es:[si + HEAP_CHUNK_SEG]
  mov bx, es:[si + HEAP_CHUNK_OFF]
  mov cx, es:[si + HEAP_CHUNK_SIZE]
  push si
  PRINTF_M `%x:%x size %u\t`, ax, bx, cx
  pop si
  add si, HEAP_SIZEOF_HCHUNK

  mov ax, es:[si + HEAP_CHUNK_SEG]
  mov bx, es:[si + HEAP_CHUNK_OFF]
  mov cx, es:[si + HEAP_CHUNK_SIZE]
  push si
  PRINTF_M `%x:%x size %u\t`, ax, bx, cx
  pop si
  add si, HEAP_SIZEOF_HCHUNK

  mov ax, es:[si + HEAP_CHUNK_SEG]
  mov bx, es:[si + HEAP_CHUNK_OFF]
  mov cx, es:[si + HEAP_CHUNK_SIZE]
  push si
  PRINTF_M `%x:%x size %u\t`, ax, bx, cx
  pop si
  add si, HEAP_SIZEOF_HCHUNK

  mov ax, es:[si + HEAP_CHUNK_SEG]
  mov bx, es:[si + HEAP_CHUNK_OFF]
  mov cx, es:[si + HEAP_CHUNK_SIZE]
  push si
  PRINTF_M `%x:%x size %u\n`, ax, bx, cx
  pop si
  add si, HEAP_SIZEOF_HCHUNK

  pop cx
  sub cx, 4
  jnz heapPrintHChunks_loop

heapPrintHChunks_end:
  pop es
  ret

%endif