#pragma inline

void main()
{
    long        l;

    asm {
        mov     ax,62000
        shld    eax,eax,16
        mov     l,eax
    }
}