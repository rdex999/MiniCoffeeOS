;
; ---------- [ BIOS PARAMETER BLOCK ] ----------
;

%ifndef BPBSTRUCT_ASM
%define BPBSTRUCT_ASM

; [[ BPB ]]

; first three bytes are a jump (to skip this data declaration) and a NOP
jmp short 3Ch
nop

bpb_oemId:                    db "MSWIN4.1"
bpb_bytesPerSector:           dw 512
bpb_sectorPerCluster:         db 4
bpb_reservedSectors:          dw 4
bpb_FATs:                     db 2
bpb_rootDirectoryEntries:     dw 512
bpb_sectorsInVolume:          dw 17984
bpb_mediaDescriptorType:      db 0F8h
bpb_sectorsPerFAT:            dw 20
bpb_sectorsPerTrack:          dw 32
bpb_numberOfHeadsOrSides:     dw 2
bpb_hiddenSectorsCount:       dw 0
                              dw 0
bpb_largeSectorCount:         dw 0
                              dw 0

;
; ---------- [ EXTENDED BIOS PARAMETER BLOCK ] ----------
;

; [[ EBPB ]]

ebpb_driveNumber:             db 80h
ebpb_flags:                   db 0
ebpb_signature:               db 29h
ebpb_volumeID:                dw 0
                              dw 0
ebpb_volumeLable:             db "MY KERNEL  " ; 11 bytes
ebpb_systemID:                db "KERNEL  "    ; 8 bytes

%endif