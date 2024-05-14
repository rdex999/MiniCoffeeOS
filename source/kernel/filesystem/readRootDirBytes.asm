;
; --------- [ READ BYTES FROM THE ROOT DIRECTORY ON A GIVEN OFFSET ] ---------
;

%ifndef READ_ROOT_DIR_BYTES_ASM
%define READ_ROOT_DIR_BYTES_ASM

; =================================================================================
; Read N bytes from the root directory, on a given offset (like readClusterBytes)
; PARAMETERS
;   - 0) ES:DI  => Buffer to store the data in
;   - 1) SI     => Byte offset to read from
;   - 2) DX     => Amount of bytes to read
; RETURNS
;   - 0) AX     => The amount of bytes read
; =================================================================================
readRootDirBytes:
  push bp
  mov bp, sp
  sub sp, 16

  ; *(bp - 2)       - Buffer segment
  ; *(bp - 4)       - Buffer offset
  ; *(bp - 6)       - Byte offset to read from
  ; *(bp - 8)       - Amount of bytes to read
  ; *(bp - 10)      - Current LBA in root directory
  ; *(bp - 12)      - Old DS segment
  ; *(bp - 14)      - Sector buffer offset (segment is SS)
  ; *(bp - 16)      - Amount of bytes read so far
  ; *(bp - 17)      - Amount of sectors left to read in the root directory

  mov [bp - 2], es                    ; Store buffer pointer
  mov [bp - 4], di                    ;
  mov [bp - 8], dx                    ; Store requested amount of bytes to read
  mov [bp - 12], ds                   ; Store old DS segment
  mov word [bp - 16], 0               ; Initialize amount of bytes read so far to 0

  mov bx, KERNEL_SEGMENT              ; DS will be used as the kernels segment
  mov ds, bx                          ;
  
  mov bx, ds:[bpb_bytesPerSector]     ; Allocate space for 1 sector
  sub sp, bx                          ;
  mov [bp - 14], sp                   ;

  ; Check if can skip any sectors, from the offset
  ; sectorsToSkip = byteOffset / sectorSize;
  ; newBytesOffset = byteOffset % sectorSize;
  mov ax, si                          ; Get the bytes offset in SI
  xor dx, dx                          ; Zero out remainder
  div bx                              ; Divide the bytes offset by the size of a sector

  mov [bp - 10], ax                   ; Store the sector offset as the LBA (will add the LBA of the root directory to it later)
  mov [bp - 6], dx                    ; Store the new bytes offset

  GET_ROOT_DIR_SIZE                   ; Get the size of the root directory (in sectors)
  sub ax, [bp - 10]                   ; Subtract from it the sectors offset
  mov [bp - 17], al                   ; Store it as the amount of sectors left to read

  GET_ROOT_DIR_OFFSET                 ; Get the root directory LBA
  add [bp - 10], ax                   ; Add it to the offset

.nextSector:
  ; if(byteOffset == 0 && bytesToRead >= sectorSize) { *** Read straight into the given buffer *** }
  ; else { *** read into the sector buffer and perform a memcpy later *** }
  cmp word [bp - 6], 0                ; Check if the bytes offset is 0
  jne .setSectorBuffer                ; If its not 0, set the destination to the sector buffer

  ; Will get here is the offset is 0
  mov ax, ds:[bpb_bytesPerSector]     ; Get the size of a  sector
  cmp [bp - 8], ax                    ; Check if the amount of bytes left to read is greater than the size of a sector
  jb .setSectorBuffer                 ; If its not greater than the size of a sector, set teh destination to the sector buffer

  ; If the bytes offset is 0 and the amount of bytes left to read is greater than the size of a sector,
  ; Set the destination to the given buffer
  mov es, [bp - 2]                    ; Set ES:BX to the sector buffer
  mov bx, [bp - 4]                    ;
  jmp .afterSetDest                   ; Proceed

.setSectorBuffer:
  mov bx, ss                          ; Set destination to the sector buffer (ES:BX = sector buffer)
  mov es, bx                          ;
  mov bx, [bp - 14]                   ;

.afterSetDest:
  mov di, [bp - 10]                   ; Get the current LBA in the root directory
  mov si, 1                           ; Amount of sector to read, set to 1
  call readDisk                       ; Read 1 sector of the root directory into the destination
  test ax, ax                         ; Check error code
  jnz .retBytesRead                   ; If there was an error, return the amount of bytes read so far

  mov ax, ds:[bpb_bytesPerSector]     ; Get the size of a sector

  ; if(byteOffset == 0 && bytesToRead >= sectorSize) { *** Skip memcpy *** }
  ; else { *** perform memcpy *** }
  cmp word [bp - 6], 0                ; Check if the bytes offset is 0       
  jne .prepMemcpy                     ; If not, prepare arguments for memcpy

  cmp word [bp - 8], ax               ; If bytes offset is 0, check if the amount of bytes left to read is greater than the size of a sector
  jae .afterMemcpy                    ; If it is greater than the size of a sector, skip memcpy

.prepMemcpy:
  ; Note: jump here with the size of a sector in AX

  ; if(bytesToRead >= sectorSize) { copySize = sectorSize - bytesOffset; }
  ; else{
  ;   if(bytesToRead + bytesOffset >= sectorSize) { copySize = bytesToRead - bytesOffset}
  ;   else { copySize = bytesToRead; }
  ; }
  cmp [bp - 8], ax                    ; Check if the amount of bytes left to read is greater than the size of a sector
  jae .setCopyMax                     ; If its greater, set the copy size to the amount of bytes left to read minus the bytes offset

  mov dx, [bp - 8]                    ; If its not greater, check if the amount of bytes left to read 
  mov bx, dx                          ; plus the offset is greater than the size of a sector
  add bx, [bp - 6]                    ;
  cmp bx, ax                          ; Check
  jbe .afterSetCopySize               ; If its not greater, then the copy size is already set to the amount of bytes left to read

  sub dx, [bp - 6]                    ; If its greater, subtract the bytes offset from the amount of bytes left ot read, and thats the copy size
  jmp .afterSetCopySize               ; Proceed and prepare more arguments for memcpy

.setCopyMax:
  mov dx, ax                          ; Get the size of a sector in DX
  sub dx, [bp - 6]                    ; Subtract from it the bytes offset, to get the amount of bytes to copy

.afterSetCopySize:
  mov bx, ss                          ; Set the source to the sector buffer, offsetted by the bytes offset
  mov ds, bx                          ;
  mov si, [bp - 14]                   ; Sector buffer
  add si, [bp - 6]                    ; Offset it by the bytes offset

  mov es, [bp - 2]                    ; Get a pointer to the given buffer
  mov di, [bp - 4]                    ;
  push dx                             ; Save amount of bytes to copy
  call memcpy                         ; Copy the data into the given buffer
  pop ax                              ; Restore amount of bytes to copy

  mov bx, KERNEL_SEGMENT              ; Set DS back to the kernels segment
  mov ds, bx                          ;

.afterMemcpy:
  add [bp - 4], ax                    ; Increase data buffer pointer by the amount of bytes just read
  add [bp - 16], ax                   ; Increase the amount of bytes read so far by the amount of bytes just read
  inc word [bp - 10]                  ; Increase current LBA address in the root directory
  mov word [bp - 6], 0                ; Set the bytes offset to 0

  dec byte [bp - 17]                  ; Decrement amount of sectors left ot read from the root directory
  jz .retBytesRead                    ; If it hit zero, return the amount of bytes read so far

  sub [bp - 8], ax                    ; Subtract the amount of bytes just read from the amount of bytes left to read
  jg .nextSector                      ; As long as its not zero, continue reading the root directory

.retBytesRead:
  mov ax, [bp - 16]                   ; Return the amount of bytes read

.end:
  mov es, [bp - 2]                    ; Restore used segments
  mov ds, [bp - 12]                   ;
  mov sp, bp                          ; Restore stack frame
  pop bp                              ;
  ret

%endif