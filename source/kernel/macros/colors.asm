;
; ---------- [ %DEFINES FOR VGA TEXT MODE COLORS ] ----------
;

%ifndef COLORS_ASM
%define COLORS_ASM

%define COLOR(txtColor, bkgColor) (txtColor | (bkgColor << 4))
%define COLOR_CHR(char, txtColor, bkgColor) (char | (COLOR(txtColor, bkgColor)) << 8)

%define VGA_TXT_BLACK 0
%define VGA_TXT_DARK_BLUE 1
%define VGA_TXT_DARK_GREEN 2
%define VGA_TXT_DARK_CYAN 3
%define VGA_TXT_RED 4
%define VGA_TXT_PURPLE 5
%define VGA_TXT_BROWN 6
%define VGA_TXT_LIGHT_GRAY 7
%define VGA_TXT_DARK_GRAY 8
%define VGA_TXT_LIGHT_BLUE 9
%define VGA_TXT_LIGHT_GREEN 0Ah
%define VGA_TXT_LIGHT_CYAN 0Bh
%define VGA_TXT_ORANGE 0Ch
%define VGA_TXT_PINK 0Dh
%define VGA_TXT_YELLOW 0Eh
%define VGA_TXT_WHITE 0Fh

%endif