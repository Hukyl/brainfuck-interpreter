.model tiny


TAIL_BYTES EQU 80h
TAIL_START EQU 81h
TAIL_LENGTH EQU 127


.code
org 100h

main PROC
    
    ; Read file: http://vitaly_filatov.tripod.com/ng/asm/asm_010.64.html

    xor   bx, bx
    mov   bl, [0h:TAIL_BYTES]
    mov   al, '$'
    mov   byte [bx+TAIL_START], al
    
    call readCommandTail

    xor   ax, ax
    mov   ah, 9
    mov   dx, offset filename
    int   21h

    ; Possible replace to `int 20h`
    ; mov ax, 4C00h  ; Close and flish all open file handles.
    ; int 21h
    ret

    ; Define variables
    code       db 10000 DUP(0)
    cells      db 10000 DUP(0)
    filename   db TAIL_LENGTH DUP(0)
    ; TODO: investigate `mov cx, 10000` -> `cld` -> `rep stosb`
    ; Book: [8], page: 137
main ENDP


readCommandTail PROC
    ; Input: 
    ;   none
    ; Registers used:
    ;   si, di, cx
    ; Output: 
    ;   [filename] string    
    cld                         ; clear direction (flag)
    mov si, TAIL_START          ; read from the tail start
    mov di, offset filename     ; write to variable
    mov cx, TAIL_LENGTH         ; set counter to length of tail
    rep movsb
    ret
readCommandTail ENDP


decodeCommand PROC NEAR
    xor ax, ax
decodeCommand ENDP


increment PROC NEAR
    xor ax, ax
increment ENDP


decrement PROC NEAR
    xor ax, ax
decrement ENDP


incrementPointer PROC NEAR
    xor ax, ax
incrementPointer ENDP


decrementPointer PROC NEAR
    xor ax, ax
decrementPointer ENDP


startLoop PROC NEAR
    xor ax, ax
startLoop ENDP


endLoop PROC NEAR
    xor ax, ax
endLoop ENDP


writeChar PROC NEAR
    xor ax, ax
writeChar ENDP


readChar PROC NEAR
    xor ax, ax
readChar ENDP


exit PROC NEAR
    xor ax, ax
exit ENDP


END main
