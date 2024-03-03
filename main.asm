.model tiny

; Agreement on code comments:
;   [8] refers to Tom Swan's book "Mastering Turbo Assmbler, 2nd edition"


;;;;;;;;;;;;;;;;;;;;;;; Constants ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CODE_SIZE   EQU 10000
CELLS_SIZE  EQU 10000

TAIL_START  EQU 81h
TAIL_LENGTH EQU 127

CR          EQU 13
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.data
    loopCounter dw 0
    isHalted    db 0
    direction   dw 1

.data?
    filename    db TAIL_LENGTH    DUP(?)
    code        db CODE_SIZE      DUP(?)
    cells       dw CELLS_SIZE     DUP(?)
    ; TODO: investigate `mov cx, 10000` -> `cld` -> `rep stosb`
    ; Book: [8], page: 137


.code
org 100h

main PROC
    mov ax, cs      ; IMPORTANT: do not change `ds` before `readCommandTail`
    mov es, ax      ; Since variables are stored in the code segment
readCommandTail:
    cld                         ; clear direction (flag)
    mov si, TAIL_START+1        ; read from tail start (ignore leading whitespace)
    mov di, offset filename     ; write to variable
    mov cl, byte [si-3]         ; number of bytes to read (ignore ^Z and whitespace char)
    dec cl
    rep movsb
; end of proc

    mov ds, ax
readCode:
    mov dx, offset filename
    mov ax, 3D00h           ; ax = Open file DOS function, al = Read-only mode
    int 21h
    ; No error checking, since is guaranteed by requirements
    mov bx, ax              ; File handle
    mov ah, 3Fh             ; Read file DOS function
    mov cx, CODE_SIZE       ; Number of bytes to read
    mov dx, offset code     ; Where to store the code
    int 21h
    mov ah, 3Eh             ; Close file DOS function
    ; bx is preset to file handle
    int 21h
; end of proc

    mov si, offset code
    mov di, offset cells
    ; Preparations for I/O
    mov dx, di    
    mov cx, 1       ; 1 bytes
decodeLoop:
    mov al, byte [si-1]
    add si, direction
    ; lodsb   ; al <- [ds:si], si <- si + 1
    call decodeCommand
    cmp al, 0
    jne decodeLoop
    ; Possible replace to `int 20h`
    ; mov ax, 4C00h  ; Close and flish all open file handles.
    ; int 21h
    ret
main ENDP


decodeCommand PROC NEAR
    ; Input:
    ;   al - command char
    ;   si - command address
    ;   di - cell address
    ; Registers used:
    ;   bx - loop counter on start of halt
    ; Output:
    ;   None
    cmp al, '['
    je startLoop
    cmp al, ']'
    je endLoop

    cmp [isHalted], 1
    je exitDecode

    cmp al, '>'
    je incrementPointer
    cmp al, '<'
    je decrementPointer
    cmp al, '+'
    je incrementValue
    cmp al, '-'
    je decrementValue
    cmp al, '.'
    je writeChar
    cmp al, ','
    je readChar
    jmp exitDecode

incrementPointer:
    add di, 2
    jmp exitDecode

decrementPointer:
    sub di, 2
    jmp exitDecode

incrementValue:
    inc word ptr [di]
    jmp exitDecode

decrementValue:
    dec word ptr [di]
    jmp exitDecode

writeChar:
    mov ah, 40h     ; Write to file DOS function
    mov bx, 1       ; Stdout
    int 21h
    jmp exitDecode

readChar:
    mov ah, 3Fh     ; Read from file DOS function        
    mov bx, 0       ; Stdin
    int 21h
    cmp byte ptr [di], CR
    jne exitDecode
    mov word ptr [di], 0FFFFh
    jmp exitDecode

exitDecode:
    ret

startLoop:
    ; If execution is not halted
    ;   If cell == 0
    ;       halt execution
    ;       remember loop counter on halt
    ;   else
    ;       increment loop counter
    ; else
    ;   if direction flag is set (moving backwards)
    ;       if loop counter == loop counter on halt
    ;           si += 2
    ;           clear direction flag
    ;           jmp startLoop
    ;       else
    ;           decrement loop counter
    ;   else
    ;       increment loop counter
    ;
    cmp isHalted, 0
    jne _sl_halted

    ; If execution is not halted (other branch in _sl_halted)
    cmp word ptr [di], 0
    jne _incrementLoopCounter

    ; If cell == 0
    mov [isHalted], 1
_rememberLoopCounter:
    mov bx, [loopCounter]
    jmp exitDecode

endLoop:
    ; if execution is halted
    ;   if direction flag is set (moving backwards)
    ;       increment loop counter
    ;   else
    ;       if loop counter == loop counter on halt
    ;           decrement loop counter
    ;           unhalt execution
    ;           jmp exitDecode
    ;       else
    ;           decrement loop counter 
    ; else
    ;   set direction flag
    ;   halt execution
    ;   remember loop counter on halt
    ;   si -= 2
    cmp isHalted, 0
    jne _el_halted

    ; If not halted
    neg [direction]
    mov [isHalted], 1
    sub si, 2
    jmp _rememberLoopCounter
_el_halted:
    ; If halted
    cmp [direction], 1
    jne _incrementLoopCounter

    ; if moving forward
    cmp bx, [loopCounter]
    jne _decrementLoopCounter

    ; Found end of loop
    mov [isHalted], 0
    jmp exitDecode

    ; For 80386/486 processor (replace after `cmp`) (decrease by 1 instruction):
    ; setnz [isHalted]        ; unhalt if equal, else keep halting
    ; jne exitDecode
    ; dec [loopCounter]
    ; jmp exitDecode

_sl_halted:
    ; If execution is halted
    cmp [direction], 1
    je _incrementLoopCounter
    
    ; If moving backwards
    cmp bx, [loopCounter]
    dec [loopCounter]
    jne exitDecode

    ; If loop counter == loop counter on halt
    add si, 2
    neg [direction]
    mov [isHalted], 0
    jmp startLoop


_incrementLoopCounter:
    inc [loopCounter]
    jmp exitDecode

_decrementLoopCounter:
    dec [loopCounter]
    jmp exitDecode

decodeCommand ENDP

END main
