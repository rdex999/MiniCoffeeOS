;
; ---------- [ READ BYTES FROM A CLUSTER CHAIN ON AN OFFSET ] ---------
;

%ifndef READ_CLUSTER_BYTES
%define READ_CLUSTER_BYTES

; Read N bytes from a cluster chain, from a given offset
; For example there is a cluster chain which data is: "some text idk"
; Reading 4 bytes on offset 3 will give you: "e te"
; PARAMETERS
;   - 0) ES:DI  => Buffer to store data in
;   - 1) SI     => Files first cluster number
;   - 2) DX     => Byte offset
;   - 3) CX     => Amount of bytes to read
; RETURNS
;   - 0) In AX, the amount of bytes read, can be less then the requested amount if an error occurred
readClusterBytes:
  push bp                                       ; Save stack frame
  mov bp, sp                                    ;
  sub sp, 14                                    ; Allocate space for local variables

  ; *(bp - 2)   - Buffer segment
  ; *(bp - 4)   - Buffer offset
  ; *(bp - 6)   - Cluster number
  ; *(bp - 8)   - Byte offset
  ; *(bp - 10)  - Amount of bytes to read
  ; *(bp - 12)  - LBA
  ; *(bp - 14)  - Old DS

  mov [bp - 2], es                              ; Store buffer pointer
  mov [bp - 4], di                              ; (ES:DI)
  mov [bp - 6], si                              ; Store first cluster number
  mov [bp - 8], dx                              ; Store bytes offset 
  mov [bp - 10], cx                             ; Store amount of bytes to read
  mov [bp - 14], ds                             ; Store old DS segment

  ; Convert the first cluster number into an LBA address
  mov di, si                                    ; Argument for clusterToLBA goes in DI, (SI is currently the cluster number)
  call clusterToLBA                             ; Convert, get LBA in AX
  mov [bp - 12], ax                             ; Save LBA

  PRINTF_M `read LBA %u\n`, ax                  ;;;;;;;;; DEBUG

  mov bx, KERNEL_SEGMENT                        ; Set DS segment to kernel segment so we can read kernel variables
  mov ds, bx                                    ;

  ; Here we calculate the new LBA. If the byte offset is greater than the amount of bytes in a sector, 
  ; then reading all sectors (from the first LBA) is pointless. We can calculate the amount of sectors to skip, and get a new LBA for it.
  ; The formula:
  ; sectorsToSkip = byteOffset / bytesPerSector
  ; newByteOffset  = byteOffset % bytesPerSector
  mov ax, [bp - 8]                              ; Get bytes offset
  mov bx, ds:[bpb_bytesPerSector]               ; Get amount of bytes in 1 sector
  xor dx, dx                                    ; Zero out remainder register
  div bx                                        ; Divide byte offset by amount of bytes in a sector

  add [bp - 12], ax                             ; Add LBA offset to the LBA
  mov ax, [bp - 12]                             ;;;;; DEBUG
  PRINTF_M `offseted LBA %u\n`, ax               ;;;;; DEBUG




.end:
  mov ds, [bp - 14]                             ; Restore old DS segment
  mov sp, bp                                    ; Restore stack frame
  pop bp                                        ;
  ret
%endif
