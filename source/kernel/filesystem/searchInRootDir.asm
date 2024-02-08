;
; ---------- [ SEARCHES FOR SOMETHING IN THE ROOT DIRECTORY ] ----------
;

%ifndef FILESYSTEM_SEARCH_IN_ROOT_DIR
%define FILESYSTEM_SEARCH_IN_ROOT_DIR

; Searches for an entry in the root directory.
; PARAMS
;   - 0) ES:DI  => File name. 11 byte string all capital.
;   - 1) DS:SI  => First entry in the root directory.
; RETURNS
;   in AX, the offset to the first byte of the files entry.
;   If not found, BX is 1, if found, BX is 0
searchInRootDir:
  push bp
  mov bp, sp
  sub sp, 12                            ; Allocate 12 bytes

  mov [bp - 2], di                      ; File name
  mov [bp - 4], si                      ; First entry in root directory
  mov [bp - 6], es                      ; Save segment registers because they will change
  mov [bp - 8], ds                      ;

  ; Get the root directory offset in sectors and store it in *(bp - 12)
  push ds                         ; Save data segment
  mov bx, KERNEL_SEGMENT          ;
  mov ds, bx                      ; Make data segment KERNEL_OFFSET to that GET_ROOT_DIR_OFFSET will read correct values
  GET_ROOT_DIR_OFFSET             ; Get the root directory offset in sectors in AX
  pop ds                          ; Restore data segment
  mov [bp - 12], ax               ; Store offset at *(bp - 12)


searchInRootDir_nextSector:
  mov word [bp - 10], 16                  ; *(bp - 8) // Directory entries counter // Reset entries counter

  ; Set the segment registers for readDIsk 
  mov bx, [bp - 8]                        ; ES:BX points to receiving data buffer
  mov es, bx                              ;
  mov bx, KERNEL_SEGMENT                  ;
  mov ds, bx                              ; Set data segment to KERNEL_OFFSET so readDisk will read correct values

  ; Set parameters for read disk. Going to read the root directory to ES:BX (1 sector)
  mov bx, [bp - 4]                        ; ES:BX points to receiving data buffer
  mov di, [bp - 12]                       ; LBA Address to read from
  mov si, 1                               ; How many sectors to read
  call readDisk

  mov bx, [bp - 6]                        ;
  mov es, bx                              ; Restore segment registers

  mov bx, [bp - 8]                        ;
  mov ds, bx                              ; Restore data segment

  test ax, ax                             ; Check if readDisk succeed
  jnz searchInRootDir_error               ; If readDisk has faild, return 1 in BX

  ; Search for the file directory entry. Increase the SI pointer by 32 each time to point to next entry.
  mov si, [bp - 4]                        ; Get first entry of root directory in SI
searchInRootDir_searchEntry:
  cmp byte ds:[si], 0                     ; If the first byte of the entry is 0 then there are no more entries left to read
  je searchInRootDir_error                ; If zero then return 1 in BX

  push si                                 ; Save current SI because REPE CMPSB will change it
  mov di, [bp - 2]                        ; Get file name in DI
  mov cx, 11                              ; Compare 11 bytes

  ; REPE  => Repeate the following instruction until CX is 0 (and decrement CX each time)
  ; CMPSB => (Compare string bytes) Compare byte at DS:SI to byte at ES:DI. If the direction flag is 0 then increment DI and SI
  repe cmpsb
  je searchInRootDir_found                ; If found then return a pointer to the file entry in AX

  pop si                                  ; Restore directory entry pointer (SI)
  add si, 32                              ; Make SI point to next directory entry

  dec word [bp - 10]                      ; Decrement nunber of entries left to read from current sector
  cmp word [bp - 10], 0                   ; If zero then read a new sector
  jne searchInRootDir_searchEntry         ; If not zero then continue searching for the file

  inc word [bp - 12]                      ; Increase the LBA for the root directory

  jmp searchInRootDir_nextSector          ; Read a new sector into memory

searchInRootDir_error:
  mov bx, 1                               ; Return 1 in BX on error
  jmp searchInRootDir_ret

searchInRootDir_found:
  lea ax, [si - 11]                       ; Return pointer to the file directory entry on success
  xor bx, bx                              ; Return status 0 (Success)
searchInRootDir_ret:
  mov sp, bp
  pop bp
  ret


%endif