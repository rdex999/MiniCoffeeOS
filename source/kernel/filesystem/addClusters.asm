;
; ---------- [ ADD CLUSTERS TO A CLUSTER CHAIN ] ----------
;

%ifndef ADD_CLUSTERS_ASM
%define ADD_CLUSTERS_ASM

; Add N clusters to a cluster chain
; PARAMS
;   - 0) DI   => First cluster of the chain (or any cluster in the chain)
;   - 1) SI   => The amount of clusters to add
; RETURNS
;   - 0) In AX, the first cluster that was added. Will return 0 on error.
addClusters:
  push bp
  mov bp, sp
  sub sp, 4

  mov [bp - 2], di
  mov [bp - 4], si

  test di, di
  jz .err

  test si, si
  jz .err

  cmp di, FAT_CLUSTER_END
  jae .err

.addLoop:
  call getNextCluster
  test bx, bx
  jnz .err

  cmp ax, FAT_CLUSTER_END
  jae .chainEnd

  mov [bp - 2], ax
  mov di, ax
  jmp .addLoop

.chainEnd:
  mov ax, [bp - 2]
  PRINTF_M `last cluster 0x%x\n`, ax


  ; Calculate the sector offset to read. Basically means that instead of reading lots of sectors, just read the one that is needed.
  ; sectorOffset = cluster / bytesPerSector;
  ; clusterIndex = cluster % bytesPerSector;


.end:
  mov sp, bp
  pop bp
  ret

.err:
  xor ax, ax
  jmp .end

%endif