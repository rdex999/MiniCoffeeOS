;
; ---------- [ INITIALIZE THE HEAP ] ----------
;

%ifndef HEAP_INIT_ASM
%define HEAP_INIT_ASM

; ; Initialize the heap
; ; Basicaly initialize the heapChunks array (set all chunks to free)
; heapInit:
;   push bp                                   ; Save stack frame
;   mov bp, sp                                ;
;   sub sp, 4                                 ; Allocate 4 bytes

;   push es                                   ; Save old segments
;   push gs                                   ;
;   mov bx, KERNEL_SEGMENT                    ; Set both ES and GS segments to kernel segments
;   mov es, bx                                ; ES will be used as the next segment in heap memory
;   mov gs, bx                                ; GS will be used as the kernel segment

;   lea si, [heapChunks]                      ; SI will be used as a pointer to a chunk in the heapChunks array
;   lea di, [kernelEnd]                       ; DI will be used as the offset for the current segment in heap memory 
;                                             ; (heap starts from the end of the kernel)

;   SAVE_BEFORE_CALL getNextSegOff, si         ; Get first segment:offset pair for the first heap chunk

;   ; Calculate the size of the chunk, as the limit is 0FFFFh (65535 bytes)
;   mov ax, 0FFFFh                            ; Set AX to chunk limit
;   sub ax, di                                ; Subtract segment offset from chunk limit, to get the chunks size

; heapInit_setFreeLoop:
;   ; When getting here, SI should point to a chunk in heapChunks, ES:DI should be a pointer to a chunk in heap memory
;   ; and AX should be the size of the chunk
;   mov gs:[si + HEAP_CHUNK_SEG16], es                   ; Set the chunks segment in heapChunks
;   mov gs:[si + HEAP_CHUNK_OFF16], di                   ; Set the chunks offset in heapChunks
;   mov gs:[si + HEAP_CHUNK_SIZE16], ax                  ; Set the chunks size in heapChunks
;   add si, HEAP_SIZEOF_HCHUNK                           ; Increase chunk pointer (in heapChunks) to point to next chunk

;   ; Save current chunk pointer (in heap memory) before changing it to the next chunk.
;   ; Basicaly each time store the previous chunk pointer
;   mov [bp - 2], es                          ; Store current chunk segment
;   mov [bp - 4], di                          ; Store current chunk offset
  
;   add di, ax                                ; Add the size of the chunk to the offset, to get to its end
;   SAVE_BEFORE_CALL getNextSegOff, si         ; Get the next chunk in ES:DI

;   ; Check if the new chunk overrides the Extended BIOS Data Area (EBDA) with a size of 0FFF0h
;   ; If it doesnt, then continue initializing chunks. If it does override it then calculate the size that wont override the EBDA and
;   ; then initialize the next chunk to this size.
;   ; if(newChunk + newChunkSize >= EBDA){
;   ;   uint16_t tmp = EBDA - (prevChunkSegment + (newChunkSize >> 4));
;   ;   if(tmp < 0) { return; }
;   ;   newSize = tmp << 4;
;   ;   continue;
;   ; }else{
;   ;   continue;
;   ; }
;   mov bx, es                                ; Get new chunk segment in BX
;   mov ax, 0FFFFh                            ; Chunk limit
;   sub ax, di                                ; Subtract the new chunks offset from the limit to get its size
;   mov cx, ax                                ; Copy the size to BX, because if we dont override the EBDA then the size must be in AX
;   shr cx, 4                                 ; Shift the size to the right by 4 bits so we can add it to the segment
;   add bx, cx                                ; Add the shifted size to the segemnt, so we can check if it overlaps the EBDA
;   cmp bx, HEAP_END_SEG                      ; Check if the new chunk overlaps the EBDA
;   jb heapInit_setFreeLoop                   ; If it doesnt overlap the EBDA with the max size, continue initializing chunks

;   ; If does overlap EBDA, then calculate the size that wont overlap it
;   mov bx, [bp - 2]                          ; Get the current chunks segment (not the new one, that is, in ES:DI)
;   mov cx, [bp - 4]                          ; Get the current chunks offset
;   mov ax, 0FFFFh                            ; Max chunk size
;   sub ax, cx                                ; Get the size of the current chunk in AX
;   shr ax, 4                                 ; Shift it 4 bits to the right so we can add it to the segment
;   add bx, ax                                ; Add the shifted offset to the segment
;   mov ax, HEAP_END_SEG                      ; The first byte of EBDA (the segment)
;   sub ax, bx                                ; Subtract from the EBDA pointer the current saegment+offset, to get the size that wont overlap
;   jc heapInit_zeroMem                       ; If the result is negative, then we are done initializing segments. Go to next stage, zero memory

;   ; If not negative, then shift the result 4 bits to the left to get the real size (because we shifted it to the right, before)
;   shl ax, 4                                 ; Shift 4 bits to the right to get the real size
;   sub ax, di                                ; The new size doesnt take in count the offset, so subtract the offset from it
;   dec ax                                    ; Decrement size by 1 so we dont overlap EBDA
;   jmp heapInit_setFreeLoop                  ; Continue. Initialize the chunk, and next time we get here we will return from the function


;   ; Zero out all chunks, also set all chunks flags
; heapInit_zeroMem:
;   lea si, [heapChunks]                      ; Get pointer to the first chunk descriptor
;   mov cx, HEAP_CHUNKS_LEN                   ; Amount of chunks
; heapInit_zeroMem_loop:
;   ; Get a pointer to the actual chunk, get its size, and set the chunk to 0
;   ; Then continue zeroing out chunks
;   mov es, gs:[si + HEAP_CHUNK_SEG16]        ; Get chunk segment
;   mov di, gs:[si + HEAP_CHUNK_OFF16]        ; Get chunk offset
;   mov dx, gs:[si + HEAP_CHUNK_SIZE16]       ; Get chunk size
;   mov byte gs:[si + HEAP_CHUNK_FLAGS8], (~HEAP_CHUNK_F_OWNED) & HEAP_CHUNK_F_ZERO   ; Set chunk flags (mark as free, and that memory is 0)
;   push si                                   ; Save chunk descriptor pointer
;   push cx                                   ; Save chunk counter
;   xor si, si                                ; Set memory to 0
;   call memset                               ; Set the chunk to 0
;   pop cx                                    ; Restore chunks counter
;   pop si                                    ; Restore 
;   add si, HEAP_SIZEOF_HCHUNK                ; Increase chunk descriptor pointer to point to next chunk descriptor
;   loop heapInit_zeroMem_loop                ; Continue zering out chunks and setting flags, until there are no more chunks (until CX == 0)

; heapInit_end:
;   pop gs                                    ; Restore segemnts
;   pop es                                    ;

;   mov sp, bp                                ; Restore stack frame
;   pop bp                                    ;
;   ret

%endif