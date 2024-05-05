;
; ---------- [ FREE DYNAMICALLI ALLOCATED MEMORY ] ----------
;

%ifndef FREE_ASM
%define FREE_ASM

; ; Free a dynamically allocated chunk of memory (only if it was allocated with malloc)
; ; PARAMS
; ;   - 0) ES:DI    => A pointer to the memory to free

; free:
;   push gs                                     ; Save old GS segment
;   mov bx, KERNEL_SEGMENT                      ; Set GS to kernel segment
;   mov gs, bx                                  ; We will use GS to access the heapChunks array

;   lea si, [heapChunks - HEAP_SIZEOF_HCHUNK]   ; Get a pointer to heapChunks (-sizeof(heapChunk) because we first increase the pointer in the loop)
;   mov cx, HEAP_CHUNKS_LEN + 1                 ; The amount of chunks to check (+1 because we first decrement (off by 1))
; free_searchLoop:
;   dec cx                                      ; Decrement chunks counter
;   jz free_end                                 ; If there are no more chunks to check then return

;   add si, HEAP_SIZEOF_HCHUNK                  ; Increase chunk pointer

;   ; First check the segment, then the offset if(segment == chunk.segment && offset == chunk.offset) 
;   ; then mark it as free in heapChunks and return
;   mov bx, es                                  ; Cant do operations on segments directly
;   cmp bx, gs:[si + HEAP_CHUNK_SEG16]          ; Check if the chunks segment is the same as the pointers segment
;   jne free_searchLoop                         ; If not then continue searching

;   cmp di, gs:[si + HEAP_CHUNK_OFF16]          ; Check if the chunks offset is the same as the pointers offset
;   jne free_searchLoop                         ; If not then continue searching

;   ; If they are equal then mark the chunk as free, and not zeroed out
;   and byte gs:[si + HEAP_CHUNK_FLAGS8], ~(HEAP_CHUNK_F_OWNED | HEAP_CHUNK_F_ZERO)

; free_end:
;   pop gs                                      ; Restore old GS segment
;   ret

%endif