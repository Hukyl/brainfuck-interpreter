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
clearUninitializedVariables:
    mov di, offset code
    mov si, di                              ; Prepare si for decodeLoop
    mov cx, CODE_SIZE+CELLS_SIZE*2          ; length of uninitialized data
    xor ax, ax                              ; Also prepare ah for Read-only mode
    rep stosb
;endp

prepareFilename:                            ; Make filename ASCIIZ
    mov dx, TAIL_START+1                    ; Account for first whitespace
    mov bx, [ds:TAIL_START-1]               ; length of command tail  
    mov byte ptr [bx-2000h+81h], 0
;endp

readCode:
    mov ah, OPEN_FILE_FN                    ; al = Read-only mode, preset by `xor ax, ax`
    ; dx is preset to ASCIIZ filename
    int 21h
    ; No error checking, since is guaranteed by requirements
    mov bx, ax              ; File handle
    mov ah, READ_FILE_FN
    dec cx                  ; Number of bytes to read (0FFFFh)
    mov dx, si              ; Where to store the code      
    int 21h
; end of proc

    mov di, offset cells
    inc cx                  ; halt loop counter (0FFFFh + 1 = 0h)
decodeLoop:
    xor bx, bx
    cmp al, '['
    jne _endLoopCheck
_startLoop:
    ; push [ address onto stack
    ; if cell == 0
    ;   increment halted loop count
    push si                 ; push [ address onto stack
    cmp word ptr [di], bx   ; bx at the start of loop =0
    jnz _loadNextChar
    inc cx
    ; no jmp, will be checked by next cmp
_endLoopCheck:
    cmp al, ']'
    jne _checkIsHalted
_endLoop:
    ; pop [ address
    ; dec halted loop count
    ; if halted loop count < 0
    ;   inc halted loop count
    ;   jmp to popped address
    pop bx                  ; pop [ address + 1
    dec cx
    jns _loadNextChar       ; if cx was 0, signed flag is set
    inc cx
    dec bx
    mov si, bx
    ; No jmp, no effect as al = ']'

_checkIsHalted:
    or cx, cx
    jnz _loadNextChar
    ; If we reached here, we know that isHalted=0
decodeModifyingCommand:
    ; Input:
    ;   al - command char
    ;   si - command address
    ;   di - cell address
    ; Registers used:
    ;   bx - file handle
    ;   cx - number of bytes for I/O
    ; Output:
    ;   None
    cmp al, '>'
    jne SHORT _decrementPointer
    inc di
    inc di

_decrementPointer:
    cmp al, '<'
    jne SHORT _incrementValue
    dec di
    dec di

_incrementValue:
    cmp al, '+'
    jne SHORT _decrementValue
    inc word ptr [di]

_decrementValue:
    cmp al, '-'
    jne SHORT _checkReadChar
    dec word ptr [di]

_checkReadChar:
    cmp al, ','
    jne _checkWriteChar
    inc cx                  ; loop halt counter=0, but #bytes has to be 1
_readChar:
    mov ah, READ_FILE_FN
    mov dx, di
    mov word ptr [di], bx   ; as bx=0
    int 21h
    dec ax                  
    or word ptr [di], ax    ; if ax was 1, do nothing, else `or` with 0FFFFh.
_checkLF:
    cmp byte ptr [di], CR   ; Ignore CR (0Dh 0Ah -> 0Ah)
    je _readChar
    dec cx                  ; restore halt counter

_checkWriteChar:
    cmp al, '.'             ; not influenced by prev command, as ax = 0 OR 1
    jne _loadNextChar
_writeChar:
    mov ah, 02h
    cmp byte ptr [di], LF   ; if see LF, also print CR
    jne _writeSimpleChar
    mov dl, CR
    int 21h
_writeSimpleChar:
    mov dx, [di]
    int 21h

_loadNextChar:
    lodsb
    or al, al
    jne decodeLoop
    int 20h
END main
