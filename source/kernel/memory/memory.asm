;
; ---------- [ FUNCTIONS FOR MANIPULATING/ALLOCATING MEMORY ] ----------
;

%ifndef MEMORY_ASM
%define MEMORY_ASM

; %include "kernel/memory/heapInit.asm"
; %include "kernel/memory/malloc.asm"
; %include "kernel/memory/free.asm"

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
; processPrintChunks:
;   push es                                         ; Save old ES segment
;   mov bx, KERNEL_SEGMENT                          ; Set ES segment to kernel segment
;   mov es, bx                                      ;

;   xor cx, cx                                      ; CX is used as a counter for how many chunks were printed 
;   lea si, [heapChunks]                            ; SI is used as a pointer to a chunk in heapChunks

; processPrintChunks_loop:
;   inc cx                                          ; Increase Chunks counter
;   cmp cx, HEAP_CHUNKS_LEN                         ; Check if the counter is greater then the amount of chunks
;   ja processPrintChunks_end                         ; If it is then return

;   push cx                                         ; Save chunk counter
;   push si                                         ; Save chunk pointer

;   ; Get chunk info and print it
;   mov ax, es:[si + HEAP_CHUNK_SEG16]              ; Get the chunks segment
;   mov bx, es:[si + HEAP_CHUNK_OFF16]              ; Get the chunks offset
;   mov cx, es:[si + HEAP_CHUNK_SIZE16]             ; Get the chunks size
;   mov dl, es:[si + HEAP_CHUNK_FLAGS8]
;   xor dh, dh
;   PRINTF_M `%x:%x %x %x\t\t`, ax, bx, cx, dx    ; Print the details
  
;   pop si                                          ; Restore chunk pointer
;   pop cx                                          ; Restore chunk counter

;   add si, HEAP_SIZEOF_HCHUNK                      ; Increase pointer to point to next chunk in heapChunks

;   test cx, 4 - 1                                  ; Check if the amount of chunks printed is dividable by 4
;   jnz processPrintChunks_loop                       ; If not then continue printing chunks

;   ; If it is dividable by 4 then print a newline, then continue printing chunks
;   push cx                                         ; Save chunks counter
;   push si                                         ; Save chunk pointer
;   PRINT_NEWLINE 1                                 ; Print the newline
;   pop si                                          ; Restore chunk pointer
;   pop cx                                          ; Restore chunk counter
;   jmp processPrintChunks_loop                       ; Continue printing chunks data

; processPrintChunks_end:
;   pop es                                          ; Restore ES segment
;   ret


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
  sub sp, 2                 ; Allocate space for local stuff
  mov [bp - 2], di          ; Save destination pointer because returning it later

  mov ax, es                ; Set AX = ES
  mov bx, ds                ; Set BX = DS   // Because cant perform operations on segments directly
  cmp ax, bx                ; Check if the destination pointer is after the source, in which case copy data from the end
  ja .setCopyFromEnd        ; If above copy from the end
  jb .setCopyFromStart      ; If the destination is below the source, copy from the start

  cmp di, si                ; If the segments are equal, check if the destination offset is above the source
  jb .setCopyFromStart      ; If its below, copy from the start
  je .end                   ; If both destination and source are equal, dont copy data, just return

.setCopyFromEnd:
  mov cx, dx                ; Get amount of bytes to copy in CX
  dec dx                    ; Need to offset the destination and source so they point to the end, but offset by the amount of bytes to copy - 1
  add di, dx                ; Offset destination
  add si, dx                ; Offset source
  std                       ; Set direction flag so MOVSB will decrement DI and SI
  rep movsb                 ; Copy the data
  cld                       ; Clear direction flag because 99% of the time its cleared
  jmp .end                  ; Return

.setCopyFromStart:
  mov cx, dx                ; Get amount of bytes to copy
  cld                       ; Clear direction flag so MOVSB will increment DI and SI
  rep movsb

.end:
  mov di, [bp - 2]          ; Restore destination pointer
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


; Copy a string into a buffer
; PARAMETERS
;   - 0) ES:DI    => The destination, where to copy the string into
;   - 1) DS:SI    => The source, the string to copy
; RETURNS
;   - 0) ES:DI    => A pointer to the destination buffer
strcpy:
  push di

  mov cx, 0FFFFh
  sub cx, di

  cld
.copyLoop:
  lodsb
  test al, al
  jz .end

  stosb
  loop .copyLoop

.end:
  stosb
  pop di
  ret

; Comapre two memory chunks
; PARAMETERS
;   - 0) ES:DI  => First chunk
;   - 1) DS:SI  => Second chunk
;   - 2) DX     => Amount of bytes to comapre
; RETURNS
;   - 0) AX     => 0 if both chunks are equal
memcmp:
  push si                       ; Save both pointers
  push di                       ;
  mov cx, dx                    ; Get the amount of bytes to comapre
  repe cmpsb                    ; Compare both chunks
  je .equal                     ; If they are equal, return 0

  mov ax, 1                     ; If not equal, return 1
  jmp .end                      ; Return

.equal:
  xor ax, ax                    ; If equal return 0
.end:
  pop di                        ; Restore first chunk pointer
  pop si                        ; Restore second chunk pointer
  ret

%endif