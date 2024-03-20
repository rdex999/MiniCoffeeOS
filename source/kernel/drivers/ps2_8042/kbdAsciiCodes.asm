;
; ---------- [ TRANSLATION FROM KEYCODES TO ASCII ] ----------
;

; Acs as an array of ascii characters, when each index in the array in a keycode, which gives you its ascii code.
; keyAsciiArr[keyCode] == asciiCode

	db 27, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 96, 49, 50, 51, 52, 53, 54, 
	db 55, 56, 57, 48, 45, 61, 8, 9, 'q', 'w', 
	db 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', 91, 93, 
	db 92, 0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 
	db 'l', 59, 39, 13, 0, 'z', 'x', 'c', 'v', 'b', 
	db 'n', 'm', 44, 46, 47, 0, 0, 0, 32, 0, 
	db 47, 42, 45, 55, 56, 57, 44, 52, 53, 54, 
	db 49, 50, 51, 48, 46, 