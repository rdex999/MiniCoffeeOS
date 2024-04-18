;
; ---------- [ FUNCTIONS FOR MANIPULATING/ALLOCATING MEMORY ] ----------
;

%ifndef MEMORY_ASM
%define MEMORY_ASM

%include "kernel/memory/heapInit.asm"
%include "kernel/memory/malloc.asm"
%include "kernel/memory/free.asm"

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
;   - ES:DI       => The original destination pointer
memcpy:
  push bp                   ; Save stack frame
  mov bp, sp                ;
  sub sp, 8                 ; Allocate 8 bytes

  mov [bp - 2], es          ; Store Destination segment
  mov [bp - 4], di          ; Store destination offset
  mov [bp - 6], si          ; Store source offset
  mov [bp - 8], dx          ; Store amount of bytes to copy

  ; Check if the destination and the source are overlapping. 
  ; But first check if their segments are the same, because if not then they are not overlapping
  mov ax, es                ; Get destination segment in AX
  mov bx, ds                ; Get source segment in BX
  cmp ax, bx                ; Check if the segments are the same
  jne memcpy_afterOverlap   ; If not then just copy normaly

  ; If the segments are the same, then check if the offsets are overlapping
  mov ax, si                ; Copy source offset to AX
  add ax, dx                ; Add to it the length (amount of bytes to copy)
  cmp ax, di                ; Check if its greater than the destination offset
  jbe memcpy_afterOverlap   ; If not then copy normaly (because they are not overlapping)

  ; If they are overlapping then get the overlap length in AX, copy the overlap to its location then change the size and copy normaly
  sub ax, di                ; Get the overlap size in AX

  ; Get pointer to the start of the overlap, in SI
  add si, dx                ; Add to the source offset the size
  sub si, ax                ; Subtract the length of the overlap, to get the start of the overlap

  ; Get a pointer to the overlaps destinations (where to copy the overlapping bytes to)
  add di, dx                ; Add to the destination offset the size
  sub di, ax                ; Subtract the length of the overlap

  ; Copy the overlapping bytes
  mov cx, ax                ; Amount of bytes to copy
  shr cx, 1                 ; Divide by 2 because copying 2 bytes at a time

  cld                       ; Clear direction flag so MOVSW will increase DI and SI
  rep movsw                 ; Copy bytes from DS:SI to ES:DI, increase SI and DI, and repeat until CX == 0
  test ax, 1                ; Because we divided it by 2, check if the amount of bytes copied is a multiple of 2
  jz memcpy_prepCopy        ; If it is, then dont copy one more byte

  ; If not a multiple of 2 then copy the last byte
  movsb                     ; Copy byte from DS:SI to ES:DI

memcpy_prepCopy:
  mov si, [bp - 6]          ; Get the original source offset
  mov di, [bp - 4]          ; Get the original destination offset
  sub dx, ax                ; Subtract the length of the overlap from the size, so we wont mess up the overlap we just fixed

memcpy_afterOverlap:
  mov cx, dx                ; Amount of bytes to copy in CX
  shr cx, 1                 ; Divide by 2 because copying 2 bytes each time
  cld                       ; Clear direction flag so MOVSW will increase SI and DI each time
  rep movsw                 ; Copy bytes from DS:SI to ES:DI, increase SI and DI, and repeat until CX == 0
  test dx, 1                ; Check if the amount of bytes copied is a multiple of 2, because we divided it by 2
  jz memcpy_end             ; If it is then return

  movsb                     ; If not then copy the last byte

memcpy_end:
  mov es, [bp - 2]          ; Return the destination segment
  mov di, [bp - 4]          ; Return the destination offset
  mov sp, bp                ; Restore stack frame
  pop bp                    ;
  ret


; Set a chunk of bytes in memory to a specific value
; PARAMS
;   - 0) ES:DI  => The destination
;   - 1) SI     => The value, lower 8 bits only
;   - 2) DX     => Count, the amount of bytes to set
; RETURNS
;   - ES:DI     => The original destination pointer, ES:DI
memset:
  mov cx, dx          ; Use CX to count amount of bytes
  mov ax, si          ; The value in AL
  mov ah, al          ; Set AH to the value. We store each time both AL and AH

  shr cx, 1           ; Divide the amount of bytes to fill by 2, because we are storing 2 bytes each time

  cld                 ; Clear direction flag so STOSW will increase DI by 2 each time
  rep stosw           ; Store AX at ES:DI, increase DI by 2 and repeat until CX is 0

  test dx, 1          ; If the count is a multiple of 2, then just return
  jz memset_end       ; If multiple of 2 then return

  stosb               ; If not, then store the last byte

memset_end:
  sub di, dx
  ret

%endif