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
    cld
    mov di, offset cells
; .data block, but with registers
    xor ax, ax              ; isHalted
    mov cx, 1               ; direction OR number of bytes for I/O
; end .data

decodeLoop:
    ; Registers used:
    ;   bx - stdin file handle OR temp register
    ;   bp - address of si on halt
    ;   check decodeModifyingCommand for more info    ;
_startLoop:
    cmp al, '['
    jne _endLoop
    ; push [ address onto stack
    ; if cell == 0 && unhalted
    ;   halt
    ;   store halt address
    push si                 ; push [ address onto stack
    mov bx, [di]
    add bl, ah
    or bx, bx               ; check if cell == 0 && unhalted (ah = 0)
    jnz _loadNextChar
    inc ah                  ; halt
    mov bp, si              ; store halt address
    ; no jmp, will be checked by next cmp
_endLoop:
    cmp al, ']'
    jne _checkIsHalted
    ; pop [ address
    ; if halted (ah=1)
    ;   if popped address == halted address
    ;       unhalt
    ; else
    ;   move execution to [ address
    pop bx                  ; pop [ address + 1
    or ah, ah
    jnz _endLoopHalted
    ; is unhalted
    dec bx                  ; to reread [ command
    mov si, bx
_endLoopHalted:
    cmp bx, bp
    jne _loadNextChar
    mov ah, 0
    ; No jmp, no effect as al = ']'

_checkIsHalted:
    cmp ah, 1
    je _loadNextChar

    call decodeModifyingCommand
    mov ah, 0               ; Restore isHalted
_loadNextChar:
    lodsb
    cmp al, 0
    jne decodeLoop
    int 20h

decodeModifyingCommand PROC
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
    xor bx, bx
    cmp al, ','
    je SHORT _readChar
    cmp al, '.'
    je SHORT _writeChar
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
    mov ah, 02h
    cmp byte ptr [di], LF   ; if see LF, also print CR
    jne _writeSimpleChar
    mov dl, CR
    int 21h
_writeSimpleChar:
    mov dx, [di]
    int 21h
    ret

_readChar:
    mov ah, READ_FILE_FN
    mov dx, di
    int 21h
    or ax, ax               ; if reached EOF
    jnz _checkLF
    mov word ptr [di], 0FFFFh
_checkLF:
    cmp byte ptr [di], CR   ; Ignore CR (ODh OAh -> OAh)
    je _readChar
    ret
decodeModifyingCommand ENDP

END main
