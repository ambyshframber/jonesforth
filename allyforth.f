: [CHAR] IMMEDIATE CHAR [COMPILE] LITERAL ;

: LOOKUPXT WORD FIND >CFA ;

: COUNT ( addr len -- addr len first )
    ( get the first character of a string and advance the string pointer )
    OVER C@
    ROT 1+
    ROT 1-
    ROT
;

: BINARY 2 BASE ! ;

: '\r' 13 ;
: '\t' 9 ;

: is_whitespace
    DUP BL =
    SWAP DUP '\r' =
    SWAP DUP '\n' =
    SWAP '\t' =
    OR OR OR
;

: scrub_space ( addr len -- a2 l2 a1 l1 )
    BEGIN COUNT is_whitespace NOT UNTIL \ skip starting whitespace
    SWAP 1- SWAP 1+ \ roll back a character

    OVER -ROT
    BEGIN COUNT is_whitespace UNTIL \ find next whitespace
    ( old_a rem_a rem_len )
    
    \ a1 = old_a
    \ l1 = rem_a old_a - 1-

    -ROT OVER >R \ puts a1 on return stack
    TUCK SWAP - 1- >R \ puts l1 on return stack
    SWAP

    BEGIN COUNT is_whitespace NOT UNTIL \ skip ending whitespace
    SWAP 1- SWAP 1+ \ roll back a character

    R> R> SWAP
;

\ string equality
: S= ( a1 l1 a2 l2 -- 1 if equal | 0 if not )
    ROT OVER ( a1 a2 l2 l1 l2 )
    = UNLESS
        2DROP DROP 0 EXIT \ length doesn't match
    THEN
    ( a1 a2 length )
    BEGIN DUP WHILE
        -ROT 2DUP C@ SWAP C@ ( length a1 a2 c1 c2 )
        = UNLESS 
            2DROP DROP 0 EXIT \ character didn't match
        THEN
        1+ SWAP 1+ ROT 1-
    REPEAT
    2DROP DROP 1 \ strings were equal
;

: (FORGET) \ forget based on pointer, not name
    DUP @ LATEST !
	HERE !
;

: ;TMP IMMEDIATE
    LATEST @ [COMPILE] LITERAL
    ' (FORGET) ,
    [COMPILE] ;
;

(
    IMMEDIATE IF

    The eponymous Jones has left us some homework: "Making [the control structures] work in immediate mode is left as an exercise for the reader."

    The solution I thought of is to compile a temporary word, EXECUTE it, then FORGET it. This requires modifications to IF and THEN, but not ELSE. The main difference is an additional value left on the stack, underneath the address of the 0BRANCH word that gets compiled. This additional value tells THEN whether to compile as normal, or end compilation and execute the word. Conveniently, we can use the xt returned by :NONAME as a flag.
)

: IF IMMEDIATE
    STATE @ IF \ compiling
        0 \ leave flag for THEN
    ELSE \ immediate
        :NONAME \ start compiling an anonymous word
    THEN
    [COMPILE] IF
;

: THEN IMMEDIATE
	[COMPILE] THEN
    
    ?DUP IF \ check flag/xt left by IF
        ' EXIT , \ finish off word
        EXECUTE \ execute it
        
        LATEST @ DUP @ LATEST !
        HERE ! \ make sure it doesn't leak

        [COMPILE] [
    THEN
;
DROP \ because the above definition uses the new version of if, it leaves the flag on the stack

: UNLESS IMMEDIATE
    STATE @ IF \ decide whether to execute or compile NOT based on STATE
        ' NOT ,
    ELSE
        NOT
    THEN
    [COMPILE] IF
;

(
    IMMEDIATE IFTHEN

    IFTHEN is a control flow word I wrote to make certain conditionals slightly smaller. It goes hand in hand with ULTHEN and IFELSE.
)

: IFTHEN IMMEDIATE
    STATE @ IF
        ' IFTHEN ,
    ELSE
        LOOKUPXT SWAP IFELSE EXECUTE DROP
    THEN
;
: ULTHEN IMMEDIATE
    STATE @ IF
        ' ULTHEN ,
    ELSE
        LOOKUPXT SWAP IFELSE DROP EXECUTE
    THEN
;

: IFELSE IMMEDIATE
    STATE @ IF
        ' IFELSE ,
    ELSE
        LOOKUPXT LOOKUPXT ROT ULTHEN SWAP DROP EXECUTE
    THEN
;

(
    LOOP WORDS

    I got bored of doing BEGIN ?DUP WHILE all the time so I wrote myself some better loop words.
)

: DFOR IMMEDIATE
    [COMPILE] BEGIN
    ' ?DUP ,
    [COMPILE] WHILE
    ' 1- ,
;

(
    MODULES

    This is a very silly and pretty unnecessary feature. Basically I thought "what if I wanna give the same simple name to multiple words" and then that led to "i can make the dictionary skip a section by frobbing the link pointers" and now we're here.
)

VARIABLE LATESTMOD

: FINDMOD ( a l -- *mod|0 )
    LATESTMOD
    BEGIN ?DUP WHILE
        DUP DUP >R 16 + C@ 63 AND SWAP 17 + SWAP ( sa sl na nl )
        2SWAP 2DUP >R >R
        S= IF
            RDROP RDROP R> EXIT
        THEN
        R> R> R> @
    REPEAT
    2DROP 0
;

(
    module descriptor "struct"

    0   backpointer to previous module OR null
    4   word to be selected when enabled
    8   word to be selected when disabled
    12  word to have its backpointer changed ("guard word")
    16  namelen + flags (1 byte)
    17  name


    namelen + flags
    bits [5,0] = length
    bit 6 = module enabled (1 when in, 0 when out)
)
