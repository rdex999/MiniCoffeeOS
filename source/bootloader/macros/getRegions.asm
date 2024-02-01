;
;   ---------- [ MACROS FOR GETTING DATA REGIONS ADDRESSES ] ----------
;

%ifndef GETREGIONS_ASM
%define GETREGIONS_ASM

; returns the size of total file allocation tables in AX (in sectors)
%macro GET_FILE_ALLOCATION_TABLES_SIZE 0

  xor ah, ah
  mov al, [bpb_FATs]
  mov bx, [bpb_sectorsPerFAT]
  mul bx

%endmacro

; returns the number of the first sector of the root directory (in AX)
%macro GET_ROOT_DIR_OFFSET 0

  GET_FILE_ALLOCATION_TABLES_SIZE    ; result in AX
  add ax, [bpb_reservedSectors]

%endmacro


; returns the size of the root directory in sectors (in AX)
%macro GET_ROOT_DIR_SIZE 0

  ; rootDirSize = (rootDirEntriesCount * 32 + bytesPerSector - 1) / bytesPerSector
  mov ax, [bpb_rootDirectoryEntries]
  mov bx, 32                          ; multiply by 32 // each entry in 32 bytes (yes, bytes and not bits)
  mul bx
  add ax, [bpb_bytesPerSector]
  dec ax
  mov bx, [bpb_bytesPerSector]
  xor dx, dx
  div bx

%endmacro

%macro GET_DATA_REGION_OFFSET 0

  xor ah, ah
  mov al, [bpb_FATs]
  mov bx, [bpb_sectorsPerFAT]
  mul bx
  add ax, [bpb_reservedSectors]
  push ax
  GET_ROOT_DIR_SIZE
  pop bx
  add ax, bx

%endmacro

%endif