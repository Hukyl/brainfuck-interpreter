.model tiny


;------------------- Constants --------------------
CODE_SIZE       EQU 10001       ; Add terminating 0
CELLS_SIZE      EQU 10001       ;

TAIL_START      EQU 81h

CR              EQU 0Dh
LF              EQU 0Ah

OPEN_FILE_FN    EQU 3Dh
CLOSE_FILE_FN   EQU 3Eh
READ_FILE_FN    EQU 3Fh
WRITE_FILE_FN   EQU 40h
;--------------------------------------------------

.data?
    code        db CODE_SIZE      DUP(?)
    cells       dw CELLS_SIZE     DUP(?)

.code
    org 100h                ; Account for 255 bytes of PSP

main:
    mov bp, cs              ; IMPORTANT: do not change `ds` before `readCommandTail`.
    mov es, bp              ; Since variables are stored in the code segment.
clearUninitializedVariables:
    mov di, offset code
    mov si, di                              ; Prepare si for decodeLoop
    mov cx, CODE_SIZE+CELLS_SIZE*2          ; length of uninitialized data
    xor ax, ax                              ; Also prepare ah for Read-only mode
    rep stosb
;endp

prepareFilename:                            ; Make filename ASCIIZ
    mov dx, TAIL_START+1                    ; Account for first whitespace
    mov bx, dx
    add bl, byte ptr [ds:TAIL_START-1]      ; length of command tail     
    mov byte ptr [bx-1], 0
;endp

readCode:
    mov ah, OPEN_FILE_FN                    ; al = Read-only mode, preset by `xor ax, ax`
    ; dx is preset to ASCIIZ filename
    int 21h
    ; No error checking, since is guaranteed by requirements
    mov ds, bp              ; move CS to DS
    mov bx, ax              ; File handle
    mov ah, READ_FILE_FN
    mov cx, CODE_SIZE       ; Number of bytes to read
    mov dx, si              ; Where to store the code      
    int 21h
    mov ah, CLOSE_FILE_FN
    ; bx is preset to file handle
    int 21h
; end of proc

execution:
    mov di, offset cells
; .data block, but with registers
    xor ax, ax              ; isHalted
    xor bp, bp              ; loopCounter
    mov cx, 1               ; direction OR number of bytes for I/O
; end .data
decodeLoop:
    call decodeCommand
    mov al, byte [si-1]
    add si, cx
    cmp al, 0
    jne decodeLoop
    int 20h

decodeCommand PROC
    ; Input:
    ;   al - command char
    ;   si - command address
    ;   di - cell address
    ; Registers used:
    ;   bx - loop counter on start of halt OR file handle (when one is used, the other one is not)
    ;   bp - loop counter
    ;   ah - whether to execute next command (ignored for `[` and `]`)
    ;   cx - direction OR number of bytes for I/O
    ; Output:
    ;   None
    cmp al, '['
    je SHORT _startLoop
    cmp al, ']'
    je SHORT _endLoop

    cmp ah, 1               ; check if isHalted
    je _exitDecodeCommand
    ; If we reached here, we know that isHalted=0
    cmp al, '>'
    je SHORT _incrementPointer
    cmp al, '<'
    je SHORT _decrementPointer
    cmp al, '+'
    je SHORT _incrementValue
    cmp al, '-'
    je SHORT _decrementValue
_IOcommands:
    mov dx, di
    xor bx, bx
    cmp al, ','
    je SHORT _readChar
    cmp al, '.'
    je SHORT _writeChar
_exitDecodeCommand:
    ret

_incrementPointer:
    add di, 2
    ret

_decrementPointer:
    sub di, 2
    ret

_incrementValue:
    inc word ptr [di]
    ret

_decrementValue:
    dec word ptr [di]
    ret

_writeChar:
    cmp byte ptr [di], LF   ; if see LF, also print CR
    jne _writeSimpleChar
    mov ah, 02h
    mov dl, CR
    int 21h
_writeSimpleChar:
    mov ah, 02h
    mov dx, [di]
    int 21h
_writeCharExit:
    ret

_readChar:
    mov ah, READ_FILE_FN
    int 21h

    or ax, ax               ; if reached EOF
    jnz _checkLF
    mov word ptr [di], 0FFFFh
_checkLF:
    cmp byte ptr [di], CR   ; Ignore CR (ODh OAh -> OAh)
    je _readChar
_readCharExit:
    ret

_startLoop:
    ; If execution is not halted
    ;   If cell == 0
    ;       halt execution
    ;       remember loop counter on halt
    ;   else
    ;       increment loop counter
    ; else
    ;   if direction flag is set (moving backwards)
    ;       if loop counter == loop counter on halt
    ;           decrement loop counter
    ;           si += 1
    ;           clear direction flag
    ;           ret
    ;       else
    ;           decrement loop counter
    ;   else
    ;       increment loop counter
    cmp ah, 1       ; check if halted
    je SHORT _startLoopHalted

    ; If execution is not halted
    cmp word ptr [di], 0
    jne SHORT _incrementLoopCounter

    ; If cell == 0
    mov ah, 1               ; Halt execution
_rememberLoopCounter:
    mov bx, bp              ; Remember the loop count
    ret

_startLoopHalted:
    ; If execution is halted
    ; FIXME: check direction flag
    cmp cl, 1               ; check if moving forward
    je SHORT _incrementLoopCounter
    
    ; If moving backwards
    cmp bx, bp              ; check if met the same loop beginning
    jne SHORT _decrementLoopCounter

    ; If loop counter == loop counter on halt
    add si, 1               ; to avoid reading the same bracket
    neg cx                  ; move forward
    mov ah, 0               ; unhalt
    dec bp                  ; decrement loop counter for it to be incremented upon startLoop
    ret

_endLoop:
    ; if execution is halted
    ;   if direction flag is set (moving backwards)
    ;       increment loop counter
    ;   else
    ;       if loop counter == loop counter on halt
    ;           decrement loop counter
    ;           unhalt execution
    ;           ret
    ;       else
    ;           decrement loop counter 
    ; else
    ;   set direction flag
    ;   halt execution
    ;   remember loop counter on halt
    ;   si -= 2
    cmp ah, 1               ; check whether is halted
    je SHORT _endLoopHalted

    ; If not halted
    neg cx                  ; move backwards
    mov ah, 1               ; halt
    sub si, 2               ; to avoid reading the same bracket
    jmp SHORT _rememberLoopCounter
_endLoopHalted:
    ; If halted
    cmp cl, 1               ; Check direction
    jne SHORT _incrementLoopCounter

    ; if moving forward
    cmp bx, bp              ; If met the same loop
    jne SHORT _decrementLoopCounter

    ; Found end of loop
    mov ah, 0               ; unhalt
    ret

    ; For 80386/486 processor (replace after `cmp`) (decrease by 1 instruction):
    ; setnz cl        ; unhalt if equal, else keep halting
    ; jne exitDecode
    ; dec sp
    ; ret

_incrementLoopCounter:
    inc bp
    ret

_decrementLoopCounter:
    dec bp
    ret

decodeCommand ENDP

END main