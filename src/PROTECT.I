MACRO protect1
mov eax,2044422144
add eax,ebx
ENDM
MACRO protect2
DB "DSMI non-commerical licence for Tuomas Koskip„„"
ENDM
MACRO protect3
DB 116,250,21,212,109,2,224,24,63,174,65,204,48,248,28,0
ENDM
MACRO protect4
DB 76 dup(?)
DD 2044460199
ENDM
protect5 = 0
