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
  ; newSeg = seg + (offset >> 4)
  mov ax, di                  ; We dont want to modify the original offset, copy it to AX
  shr ax, 4                   ; Shift offset 4 bits to the left, so we can add it to the segment
  mov bx, es                  ; Cant make operations on segment registers directly
  add bx, ax                  ; Add bitwise shift result to the segment
  mov es, bx                  ; Set new segment to ES

  ; newOffset = offset & 0Fh
  and di, 0Fh                 ; bitwise and on the offset (DI) with 0Fh, to get just the lower 4 bits
  ret

; Initialize the heap
; Basicaly initialize the heapChunks array (set all chunks to free)
heapInit:
  push bp                                   ; Save stack frame
  mov bp, sp                                ;
  sub sp, 4                                 ; Allocate 4 bytes

  push es                                   ; Save old segments
  push gs                                   ;
  mov bx, KERNEL_SEGMENT                    ; Set both ES and GS segments to kernel segments
  mov es, bx                                ; ES will be used as the next segment in heap memory
  mov gs, bx                                ; GS will be used as the kernel segment

  lea si, [heapChunks]                      ; SI will be used as a pointer to a chunk in the heapChunks array
  lea di, [kernelEnd]                       ; DI will be used as the offset for the current segment in heap memory 
                                            ; (heap starts from the end of the kernel)

  SAVE_BEFORE_CALL getNextSegOff, si         ; Get first segment:offset pair for the first heap chunk

  ; Calculate the size of the chunk, as the limit is 0FFFFh (65535 bytes)
  mov ax, 0FFFFh                            ; Set AX to chunk limit
  sub ax, di                                ; Subtract segment offset from chunk limit, to get the chunks size

heapInit_setFreeLoop:
  ; When getting here, SI should point to a chunk in heapChunks, ES:DI should be a pointer to a chunk in heap memory
  ; and AX should be the size of the chunk
  mov word gs:[si + HEAP_CHUNK_SEG16], es                   ; Set the chunks segment in heapChunks
  mov word gs:[si + HEAP_CHUNK_OFF16], di                   ; Set the chunks offset in heapChunks
  mov word gs:[si + HEAP_CHUNK_SIZE16], ax                  ; Set the chunks size in heapChunks
  mov byte gs:[si + HEAP_CHUNK_FLAGS8], 0                   ; Mark the chunk as free, and cancel all flags (HEAP_CHUNK_F_OWNED = 1)
  add si, HEAP_SIZEOF_HCHUNK                                ; Increase chunk pointer (in heapChunks) to point to next chunk

  ; Save current chunk pointer (in heap memory) before changing it to the next chunk.
  ; Basicaly each time store the previous chunk pointer
  mov [bp - 2], es                          ; Store current chunk segment
  mov [bp - 4], di                          ; Store current chunk offset
  
  add di, ax                                ; Add the size of the chunk to the offset, to get to its end
  SAVE_BEFORE_CALL getNextSegOff, si         ; Get the next chunk in ES:DI

  ; Check if the new chunk overrides the Extended BIOS Data Area (EBDA) with a size of 0FFF0h
  ; If it doesnt, then continue initializing chunks. If it does override it then calculate the size that wont override the EBDA and
  ; then initialize the next chunk to this size.
  ; if(newChunk + newChunkSize >= EBDA){
  ;   uint16_t tmp = EBDA - (prevChunkSegment + (newChunkSize >> 4));
  ;   if(tmp < 0) { return; }
  ;   newSize = tmp << 4;
  ;   continue;
  ; }else{
  ;   continue;
  ; }
  mov bx, es                                ; Get new chunk segment in BX
  mov ax, 0FFFFh                            ; Chunk limit
  sub ax, di                                ; Subtract the new chunks offset from the limit to get its size
  mov cx, ax                                ; Copy the size to BX, because if we dont override the EBDA then the size must be in AX
  shr cx, 4                                 ; Shift the size to the right by 4 bits so we can add it to the segment
  add bx, cx                                ; Add the shifted size to the segemnt, so we can check if it overlaps the EBDA
  cmp bx, HEAP_END_SEG                      ; Check if the new chunk overlaps the EBDA
  jb heapInit_setFreeLoop                   ; If it doesnt overlap the EBDA with the max size, continue initializing chunks

  ; If does overlap EBDA, then calculate the size that wont overlap it
  mov bx, [bp - 2]                          ; Get the current chunks segment (not the new one, that is, in ES:DI)
  mov cx, [bp - 4]                          ; Get the current chunks offset
  mov ax, 0FFFFh                            ; Max chunk size
  sub ax, cx                                ; Get the size of the current chunk in AX
  shr ax, 4                                 ; Shift it 4 bits to the right so we can add it to the segment
  add bx, ax                                ; Add the shifted offset to the segment
  mov ax, HEAP_END_SEG                      ; The first byte of EBDA (the segment)
  sub ax, bx                                ; Subtract from the EBDA pointer the current saegment+offset, to get the size that wont overlap
  jc heapInit_end                           ; If the result is negative, then we are done initializing segments. Just return

  ; If not negative, then shift the result 4 bits to the left to get the real size (because we shifted it to the right, before)
  shl ax, 4                                 ; Shift 4 bits to the right to get the real size
  dec ax                                    ; Decrement by 1, so wont overlap EBDA
  jmp heapInit_setFreeLoop                  ; Continue. Initialize the chunk, and next time we get here we will return from the function

heapInit_end:
  pop gs                                    ; Restore segemnts
  pop es                                    ;

  mov sp, bp                                ; Restore stack frame
  pop bp                                    ;
  ret

; Print the heapChunks array
;;;;;;; THIS IS A DEBUG FUNCTION
heapPrintHChunks:
  push es                                         ; Save old ES segment
  mov bx, KERNEL_SEGMENT                          ; Set ES segment to kernel segment
  mov es, bx                                      ;

  xor cx, cx                                      ; CX is used as a counter for how many chunks were printed 
  lea si, [heapChunks]                            ; SI is used as a pointer to a chunk in heapChunks

heapPrintHChunks_loop:
  inc cx                                          ; Increase Chunks counter
  cmp cx, HEAP_CHUNKS_LEN                         ; Check if the counter is greater then the amount of chunks
  ja heapPrintHChunks_end                         ; If it is then return

  push cx                                         ; Save chunk counter
  push si                                         ; Save chunk pointer

  ; Get chunk info and print it
  mov ax, es:[si + HEAP_CHUNK_SEG16]              ; Get the chunks segment
  mov bx, es:[si + HEAP_CHUNK_OFF16]              ; Get the chunks offset
  mov cx, es:[si + HEAP_CHUNK_SIZE16]             ; Get the chunks size
  mov dl, es:[si + HEAP_CHUNK_FLAGS8]
  xor dh, dh
  PRINTF_M `%x:%x %x %x\t\t`, ax, bx, cx, dx    ; Print the details
  
  pop si                                          ; Restore chunk pointer
  pop cx                                          ; Restore chunk counter

  add si, HEAP_SIZEOF_HCHUNK                      ; Increase pointer to point to next chunk in heapChunks

  test cx, 4 - 1                                  ; Check if the amount of chunks printed is dividable by 4
  jnz heapPrintHChunks_loop                       ; If not then continue printing chunks

  ; If it is dividable by 4 then print a newline, then continue printing chunks
  push cx                                         ; Save chunks counter
  push si                                         ; Save chunk pointer
  PRINT_NEWLINE                                   ; Print the newline
  pop si                                          ; Restore chunk pointer
  pop cx                                          ; Restore chunk counter
  jmp heapPrintHChunks_loop                       ; Continue printing chunks data

heapPrintHChunks_end:
  pop es                                          ; Restore ES segment
  ret


; Copies a chunk of memory from one location to another.
; PARAMS
;   - 0) ES:DI    => Memory to copy to, the destination.
;   - 1) DS:SI    => Memory to copy data from, the source.
;   - 2) DX       => The amount of memory to copy, in bytes.
; RETURNS
;   - This functions return type is void.
memcpy:
  mov cx, dx        ; Move the amount to copy to CX, as it is used as a counter for the REP instruction
  
  shr cx, 1         ; Divide amount of bytes to copy by 2, because we will copy it by 2 bytes at a time (word)
  
  cld               ; Clear direction flag so MOVSW will increase DI by 2 each time
  rep movsw         ; Copy 2 bytes from DS:SI to ES:DI, and repeat until CX is 0

  test dx, 1        ; Test if the amount of bytes to copy (the parameter) is a multiple of 2 (if its not, then need to copy one more byte)
  jz memcpy_end     ; If it is, then just return

  movsb             ; If not a multiple of 2 then copy the last byte and then return

memcpy_end:
  ret

%endif