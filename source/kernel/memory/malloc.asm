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
  push bp                                                     ; Save stack frame
  mov bp, sp                                                  ;
  sub sp, 2

  push gs                                                     ; Save old ES segment

  mov dx, di                                                  ; Requested size of chunk in DX
  xor di, di                                                  ; Zero out result pointer, so it points to null by default
  mov es, di                                                  ; Also segment
  cmp dx, HEAP_MAX_CHUNK_SIZE                                 ; Check if the requested size is above the limit
  ja malloc_end                                               ; If it is then return, with the result pointer already set to null

  mov bx, KERNEL_SEGMENT                                      ; Set GS to kernel segment
  mov gs, bx                                                  ; it will be used to access the heapChunks array

  lea si, [heapChunks - HEAP_SIZEOF_HCHUNK]                   ; Get a pointer to (heapChunks - sizeof(heapChunks))
                                                              ; (bacause we increment first, inside the loop)
  mov bx, 0FFFFh                                              ; BX is used as the minimum chunk size. (We want to allocate the smallest one)
  mov cx, HEAP_CHUNKS_LEN + 1                                 ; CX will hold the amount of chunks left to check
                                                              ; used to determin when to return from the function

malloc_searchChunkLoop:
  dec cx                                                      ; Decrement chunks counter
  jz malloc_checkRes                                          ; If there are no more chunks to check then return

  add si, HEAP_SIZEOF_HCHUNK                                  ; Increase the pointer to point to the next chunk (it start at heapChunks - sizeof(heapChunk))
  
  test byte gs:[si + HEAP_CHUNK_FLAGS8], HEAP_CHUNK_F_OWNED   ; Check if the chunk is marked as owned
  jnz malloc_searchChunkLoop                                  ; If it is then continue searching

  ; If the chunk if free, then check if its size is greater or equal to the size requested
  ; If it is greater then check if its the smallest size fount
  ; if(heapChunks[i].size >= requestedSize){
  ;   if(heapChunks[i].size < minSizeFound){
  ;     minSizeFound = heapChunks[i].size;
  ;     smallestChunkIdx = i;
  ;   } else { continue; }
  ; } else {continue; }
  cmp gs:[si + HEAP_CHUNK_SIZE16], dx                         ; Check if the current chunk size is big enough for the requested size
  jb malloc_searchChunkLoop                                   ; If not then continue searching

  cmp gs:[si + HEAP_CHUNK_SIZE16], bx                         ; If big enough then check if its the smallest one so far
  jae malloc_searchChunkLoop                                  ; If not then continue searching (the first one will not jump)

  mov di, si                                                  ; If it is the smallest one so far, then mark it as the smallest one (store pointer in DI)
  mov bx, gs:[si + HEAP_CHUNK_SIZE16]                         ; Set the chunks size as the smallest so far
  jmp malloc_searchChunkLoop                                  ; Continue searching chunks

malloc_checkRes:
  test di, di                                                 ; Check if a chunk was found (DI will be 0 if no chunk was found)
  jz malloc_end                                               ; If not found then return with null (as ES and DI are both 0)

  ; Otherwise if a chunk was found then get a pointer to it and return
  mov [bp - 2], di                                            ; Store the chunk descriptor pointer
  SAVE_BEFORE_CALL heapFindNullChunk, dx                      ; Save the requested size, and get a pointer to a null chunk descriptor in ES:DI

  mov si, di                                                  ; Pointer to null chunk descriptor in ES:SI
  mov di, [bp - 2]                                            ; Pointer to found chunk (the one that we return) in GS:DI

  mov cx, gs:[di + HEAP_CHUNK_SIZE16]                         ; Get the found chunk original size in CX
  mov gs:[di + HEAP_CHUNK_SIZE16], dx                         ; Update the found chunk size to the requested size
  mov ax, gs:[di + HEAP_CHUNK_SEG16]                          ; Get the found chunks segment in AX
  mov bx, gs:[di + HEAP_CHUNK_OFF16]                          ; Get the found chunks offset in BX
  or byte gs:[di + HEAP_CHUNK_FLAGS8], HEAP_CHUNK_F_OWNED     ; Mark the found chunk as owned
  and byte gs:[di + HEAP_CHUNK_FLAGS8], ~HEAP_CHUNK_F_ZERO     ; Mark the found chunk as not zeroed

  ; We got a null chunk descriptor at ES:SI, now we need to update it so it starts from the end of the found chunk,
  ; and update some of its properties
  add bx, dx                                                  ; The new chunks offset will be found.offset + requestedSize
  sub cx, dx                                                  ; The new chunks size will be found.size - requestedSize

  mov es:[si + HEAP_CHUNK_SEG16], ax                          ; Set new chunk segment
  mov es:[si + HEAP_CHUNK_OFF16], bx                          ; Set new chunk offset
  mov es:[si + HEAP_CHUNK_SIZE16], cx                         ; Set new chunk size
  and byte es:[si + HEAP_CHUNK_FLAGS8], ~HEAP_CHUNK_F_OWNED   ; Set flags, mark it as free

  mov al, gs:[di + HEAP_CHUNK_FLAGS8]
  mov es, gs:[di + HEAP_CHUNK_SEG16]                          ; Get the segment of the found chunk
  mov di, gs:[di + HEAP_CHUNK_OFF16]                          ; Get the offset of the found chunk

  test al, HEAP_CHUNK_F_ZERO                                  ; Check if the chunks memory is set to 0
  jnz malloc_end                                              ; If it is then just return a pointer to the chunk

  ; If not zero then zero it and return a pointer to the chunk
  xor si, si                                                  ; Set memory to 0
  call memset                                                 ; Zero out the chunk. Destination is in ES:DI anmd count already in DX

malloc_end:
  pop gs                                                      ; Restore GS segment
  mov sp, bp                                                  ; Restore stack frame
  pop bp                                                      ;
  ret


; Finds a null chunk in heapChunks, and return a pointer to it
; Takes no parameters
; RETURNS
;   - ES:DI   => A pointer to the chunk descriptor in heapChunks. Returns null if there is no null chunk
heapFindNullChunk:
  mov bx, KERNEL_SEGMENT                      ; Set ES to kernel segment.
  mov es, bx                                  ; I Dont save ES because its used as the return value
  
  lea si, [heapChunks - HEAP_SIZEOF_HCHUNK]   ; Get a pointer to (heapChunks - sizeof(heapChunks)) because we first increase the pointer in the loop
  mov cx, HEAP_CHUNKS_LEN                     ; CX will count the amount of chunks left to check
  xor di, di                                  ; Zero out result pointer, so if we dont find a chunk we return null

heapFindNullChunk_loop:
  dec cx                                      ; Decrement amount of chunks left to check
  jz heapFindNullChunk_end                    ; If there are no more chunks left to check then return

  add si, HEAP_SIZEOF_HCHUNK                  ; Increase heapChunks pointer to point to the next heap chunk descriptor

  cmp word [si + HEAP_CHUNK_SEG16], 0         ; Check if the chunks segment is 0. (only a null chunk would have such segment)
  jne heapFindNullChunk_loop                  ; If its not zero (meaning its not a null chunk) then continue searching

  mov di, si                                  ; If it is a null chunk then set result pointer to point to the chunk descriptor and reutrn

heapFindNullChunk_end:
  ret

%endif