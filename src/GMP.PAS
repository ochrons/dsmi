Program PascalModulePlayer; { (C) 1992 Jussi Lahdenniemi }
Uses DOS,crt,MCP,AMP,SDI__SB,LoadM,Memory,GetCPU,Csupport,PuraPCJ,GMPgfx,det_SB;

Type TBitBlk = Record
                 x,y : word;
                 pic : pointer;
                 siz : word;
               end;

     TLineTable = Array[0..639] of byte;

Procedure LineRout(Mista,Mihin:Word;Var Taulu:TLineTable); Assembler;
Asm
        Push DS
        Push ES
        Push DI
        Push SI
        Push AX
        Push BX
        Push CX
        Push DX
        Mov  ES,Word ptr [Taulu+2]
        Mov  DI,Word ptr [Taulu]
        Mov  AX,[Mista]
        Cmp  AX,[Mihin]
        Jg   @@99

        { Now 'Mista' < 'Mihin', so all the components > 0. }

        Mov  CX,[Mihin]
        Mov  BX,CX
        Mov  DX,AX
        Xor  AL,AL
        Cld
        Cmp  CX,0
        Je   @@00
        Cmp  CX,2000h
        Jb   @@01
@@55:   Jmp  @@00
@@01:   Inc  AL
        Sub  BX,DX
        Ja   @@02
        Stosb
        Xor  AL,AL
        Add  BX,[Mihin]
        Cmp  CX,2000h
        Ja   @@55
@@02:   Loop @@01
        Jmp  @@00

        { The other part where 'Mista' > 'Mihin' }

@@99:
        Mov  CX,[Mista]
        Mov  BX,CX
        Mov  DX,[Mihin]
        Xor  AL,AL
        Cld
@@11:   Sub  BX,DX
        Ja   @@13
        Mov  AL,1
        Stosb
        Add  BX,[Mista]
        Jmp  @@12
@@13:   Xor  AL,AL
        Stosb
@@12:   Loop @@11

@@00:   Pop  DX
        Pop  CX
        Pop  BX
        Pop  AX
        Pop  SI
        Pop  DI
        Pop  ES
        Pop  DS

end;

Procedure Zoom(Bitblk:TBitBlk;x,y:integer;newx:word);
Begin
Asm
                Jmp     @@CodeStart

@@xsiz:         dw      0
@@ysiz:         dw      0
@@newx:         dw      0

@@ltable:       dd      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                dd      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                dd      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                dd      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                dd      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                dd      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                dd      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                dd      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

@@CodeStart:    Push    ds
                Mov     ax,[bitblk.x]
                Mov     word ptr [@@xsiz],ax
                Mov     ax,[bitblk.y]
                Mov     word ptr [@@ysiz],ax
                Mov     ax,[newx]
                Mov     word ptr [@@newx],ax

                Push    ax
                Mov     ax,word ptr [@@xsiz]
                Push    ax
                Push    cs
                Push    offset @@ltable
                Call    LineRout

                Mov     ax,[y]
                Xor     dx,dx
                Mov     bx,320
                Mul     bx
                Add     ax,[x]
                Mov     di,ax
                Mov     ax,0a000h
                Mov     es,ax
                Lds     si,[bitblk.pic]

                Clc
                Mov     dx,word ptr [@@ysiz]
                Mov     cx,320
                Sub     cx,word ptr [@@newx]
                Sub     ah,ah
@@Outer:        Sub     bx,bx
@@Inner:        Mov     al,byte ptr [ds:si]
                Stosb
                Mov     al,byte ptr [@@ltable+bx]
                Add     si,ax
                Inc     bx
                Cmp     bx,word ptr [@@newx]
                Jne     @@Inner
                Add     di,cx
                Dec     dx
                Jnz     @@Outer
                Pop     ds
end;
end;

Procedure GetBlock(var p:pointer;xs,ys,xe,ye:word);
var Sg,Os:Word;
begin
  p:=malloc((xe-xs+1)*(ye-ys+1)+4);
  sg:=seg(p^);
  os:=ofs(p^);
  asm
                push    ds
                mov     ax,ys
                mov     bx,320
                mul     bx
                add     ax,xs
                mov     si,ax
                mov     cx,xe
                sub     cx,xs
                inc     cx
                mov     bx,320
                sub     bx,cx
                mov     dx,ye
                sub     dx,ys
                inc     dx
                push    cx
                mov     ax,sg
                mov     es,ax
                mov     di,os
                mov     ax,0a000h
                mov     ds,ax
                Mov     ax,cx
                cld
                Stosw
                Mov     ax,dx
                Stosw
@@Outer:        pop     cx
                push    cx
                rep     movsb
                add     si,bx
                dec     dx
                jnz     @@Outer
                pop     cx
                pop     ds
  end;
end;

Procedure PutBlock(p:pointer;xs,ys,ycs,yce:word);
var sg,os:word;
begin
  sg:=seg(p^);
  os:=ofs(p^);
  asm
                push    ds
                mov     ax,ys
                add     ax,ycs
                mov     bx,320
                mul     bx
                add     ax,xs
                mov     di,ax
                mov     si,os
                mov     ax,sg
                mov     ds,ax
                Lodsw
                Mov     cx,ax
                Mov     bx,320
                Sub     bx,cx
                Lodsw
                Mov     dx,ax
                sub     dx,ycs
                sub     dx,yce
                push    dx
                mov     ax,ycs
                mul     cx
                add     si,ax
                pop     dx
                cld
                mov     ax,0a000h
                mov     es,ax
                Push    cx
@@Outer:        pop     cx
                push    cx
                rep     movsb
                add     di,bx
                dec     dx
                jnz     @@Outer
                pop     cx
                pop     ds
  end;
end;

Function BlockX(P:pointer):Word;
Begin
  Blockx:=memw[seg(p^):ofs(p^)];
end;

Function BlockY(P:Pointer):Word;
Begin
  Blocky:=memw[seg(p^):ofs(p^)+2];
end;

Const ltr : string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!"#$%&/()=?{[]}+'+
                     '\''^~*,.-<>|_;:abcdefghijklmnopqrstuvwxyz@';
Procedure Fnt2Blk(ch:char;Var pic:tbitblk);
Const Space:Array[0..32] of word=(4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
Var w:word;
    off,sg:word;
Begin
  if pos(ch,ltr)=0 then begin
    sg:=seg(space);
    off:=ofs(space);
  end else begin
    sg:=seg(FontData);
    off:=ofs(FontData)+1;
    for w:=2 to pos(ch,ltr) do inc(off,2+memw[sg:off]*16);
  end;
  pic.x:=memw[sg:off];
  pic.y:=16;
  pic.pic:=ptr(sg,off+2);
  pic.siz:=pic.x*16;
end;

Procedure Word2Blk(s:string;Var pic:tbitblk);
Var w,w2:word;
    p:tbitblk;
    sp,op,sg,og,gl:word;
Begin
  pic.x:=0;
  pic.y:=16;
  gl:=0;
  for w:=1 to length(s) do begin
    Fnt2Blk(s[w],p);
    inc(gl,p.x+2);
  end;
  if gl>=4 then dec(gl,2) else gl:=2;
  getmem(pic.pic,gl*16);
  fillchar(pic.pic^,gl*16,0);
  pic.siz:=gl*16;
  sg:=seg(pic.pic^);
  og:=ofs(pic.pic^);
  for w:=1 to length(s) do begin
    Fnt2Blk(s[w],p);
    sp:=seg(p.pic^);
    op:=ofs(p.pic^);
    for w2:=0 to 15 do
      move(mem[sp:op+w2*p.x],mem[sg:og+w2*gl+pic.x],p.x);
    inc(pic.x,p.x+2);
  end;
  if pic.x>=4 then dec(pic.x,2) else pic.x:=2;
end;

Procedure wr;
begin
  repeat until port[$3da] and 8<>0 ;
  repeat until port[$3da] and 8=0 ;
end;

procedure break(s:string);
var i:integer;
begin
  asm
    mov ax,3
    int 10h
  end;
  writeln(' * ERROR * ',s);
  mcpClose;
  ampClose;
  tsClose;
  halt(1);
end;

Procedure clr(str:word;xc:word);
begin
asm
                mov     di,[str]
                mov     ax,0a000h
                mov     es,ax
                mov     dx,16
                mov     al,240
                mov     bx,320
                sub     bx,[xc]
                cld
@@a:            mov     cx,[xc]
                rep     stosb
                inc     al
                add     di,bx
                dec     dx
                jnz     @@a
end;
end;

Procedure clrb(str:word;xc:word);
begin
asm
                mov     di,[str]
                mov     ax,0a000h
                mov     es,ax
                mov     dx,16
                sub     al,al
                mov     bx,320
                sub     bx,[xc]
                cld
@@a:            mov     cx,[xc]
                rep     stosb
                add     di,bx
                dec     dx
                jnz     @@a
end;
end;

Procedure clrg(str:word;xc:word);
begin
asm
                mov     di,[str]
                mov     ax,0a000h
                mov     es,ax
                mov     dx,16
                mov     al,224
                mov     bx,320
                sub     bx,[xc]
                cld
@@a:            mov     cx,[xc]
                rep     stosb
                inc     al
                add     di,bx
                dec     dx
                jnz     @@a
end;
end;

Procedure HelpThem;
begin
  clrscr;
  TextColor(brown);
  Textbackground(blue);
  write('  G M P  -  Graphical Module Player                 (C) 1992 Jussi Lahdenniemi  ');
  TextColor(Lightgreen);
  TextBackground(black);
  Writeln;
  Writeln(' This program uses the DSMI from Otto Chrons.');
  Writeln(' C to Pascal conversion by Jussi Lahdenniemi');
  Writeln;
  Writeln;
  TextColor(Yellow);
  Writeln(' Usage : ');
  TextColor(Lightred);
  Writeln(' GMP modulename [-?] [-h] [-sxxx] [-o] [-l] [-dx] [-z]');
  Writeln;
  TextColor(LightMagenta);
  Write(' -?, -h   ');
  TextColor(LightCyan);
  Writeln('Show this help screen');
  TextColor(LightMagenta);
  Write(' -s       ');
  TextColor(LightCyan);
  Writeln('Sampling rate (4000-22000)');
  TextColor(LightMagenta);
  Write(' -o       ');
  TextColor(LightCyan);
  Writeln('Scramble module order');
  TextColor(LightMagenta);
  Write(' -l       ');
  TextColor(LightCyan);
  Writeln('No looping');
  TextColor(LightMagenta);
  Write(' -d       ');
  TextColor(LightCyan);
  Writeln('Bar drawing method in the player :');
  Writeln('            0. Sample names in the left');
  Writeln('            1. Sample names in the center');
  TextColor(LightMagenta);
  Write(' -z       ');
  TextColor(LightCyan);
  Writeln('Remove zooming from instrument names (recommended for slow machines)');
  Writeln;
  Writeln;
  Halt(0);
end;

var r,rg:registers;
    b:tbitblk;
    f:file;
    modn:string;
    d:dirstr;
    e:namestr;
    g:extstr;
    module:PModule;
    pro:boolean;
    i:integer;
    Scard:TSoundCard;
    trackData:PTrackData;
    trackTime:array[0..3] of word;
    prc:array[0..3] of integer;
    cnt:longint;
    stim,etim:longint;
    pp:Pal256T;
    ppp:PPic256T;
    s:string;

const DrawMethod : byte    = 0;
      Srate      : word    = 16000;
      Scramble   : boolean = false;
      LoopIt     : boolean = true;
      zoomThem   : boolean = true;

      maxNames   = 200;
      modNameCnt : word = 0;
      modPointer : word = 1;
      masterVol  : byte = 64;

      BlkCnt     = 18;
      BlkData    : Array[0..BlkCnt-1,0..3] of word = (
                   (0,0,14,18),
                   (0,20,14,36),
                   (16,0,30,18),
                   (16,20,30,36),
                   (63,3,201,36),
                   (0,38,243,50),
                   (0,52,243,61),
                   (0,63,243,71),
                   (0,73,243,85),
                   (0,87,243,98),
                   (0,100,243,108),
                   (0,110,243,119),
                   (0,121,243,132),
                   (0,134,243,146),
                   (0,148,243,160),
                   (0,162,243,171),
                   (0,173,243,182),
                   (0,184,243,196));

      helpStart  = 40;
      helpEnd    = 120;
      helpSpace  = 2;

      hrCount    = 13;
      hbOrder    : Array[0..hrCount-1] of byte = (14,13,5,6,15,8,9,16,10,17,12,11,7);

      scrTitle   = 1;
      scrHelp    = 2;
      scrInfo    = 3;

Var   modNames   : Array[1..MaxNames] of string[30];
      beforeMod  : Pointer;
      ch         : Char;

      HelpBlks   : Array[0..BlkCnt-1] of pointer;
      helpRow    : word;
      firstTopic : word;
      scrUp,
      scrDn      : boolean;
      screen     : word;
      first      : boolean;

      is         : TMCPstruct;
      playBuf    : pointer;
      tableBuf   : pointer;

Procedure FindMods(name:String);
Var sr:SearchRec;
    ps:dirStr;
    ns:nameStr;
    es:extStr;
begin
  Fsplit(s,ps,ns,es);
  FindFirst(name,ReadOnly+Archive,sr);
  while dosError=0 do begin
    inc(modNameCnt);
    modNames[modNameCnt]:=ps+sr.name;
    FindNext(sr);
  end;
end;

procedure UpdScr;
begin
  if scrUp then putblock(helpBlks[0],0,0,0,0) else putblock(helpBlks[2],0,0,0,0);
  if scrDn then putblock(helpBlks[1],319-blockX(helpBlks[1]),0,0,0) else
                putblock(helpBlks[3],319-blockX(helpBlks[3]),0,0,0);
end;

procedure updateInfo;
var s:string;
begin
  s:=ascz2str(module^.name);
  Word2Blk(s,b);
  Clrb(43*320+104,215);
  if b.x>0 then
  if b.x<215 then
    zoom(b,104,43,b.x) else
    zoom(b,104,43,215);
  freemem(b.pic,b.siz);
  str(module^.size div 1024,s);
  s:=s+'k';
  Word2Blk(s,b);
  Clrb(63*320+72,59);
  zoom(b,72,63,b.x);
  freemem(b.pic,b.siz);
  str(memavail div 1024,s);
  s:=s+'k';
  Word2Blk(s,b);
  Clrb(83*320+176,143);
  zoom(b,176,83,b.x);
  freemem(b.pic,b.siz);
  str(modNameCnt,s);
  Word2Blk(s,b);
  Clrb(103*320+217,102);
  zoom(b,217,103,b.x);
  freemem(b.pic,b.siz);
  s:='';
  if (ampGetModuleStatus and MD_Playing)>0 then s:='Playing';
  if (ampGetModuleStatus and MD_Paused)>0 then s:='Paused';
  Word2Blk(s,b);
  clrb(63*320+227,92);
  if b.x>0 then zoom(b,227,63,b.x);
  freemem(b.pic,b.siz);
end;

Label Quit,TryNext;

begin
  {$I-}
  if paramcount=0 then HelpThem;
  modn:='';
  for r.ax:=1 to paramcount do begin
    s:=paramstr(r.ax);
    if (s[1]='-') or (s[1]='/') then
      case upcase(s[2]) of
        'S' : begin
                delete(s,1,2);
                val(s,r.bx,integer(r.cx));
                if (r.bx>=4) and (r.bx<=22) then r.bx:=r.bx*1000;
                if (r.bx<4000) or (r.bx>22000) then Break('Sampling rate must be >=4000 and <=22000.');
                srate:=r.bx;
              end;
        'D' : begin
                delete(s,1,2);
                val(s,r.bx,integer(r.cx));
                if r.bx>1 then Break('Drawing method must be 0 or 1.');
                DrawMethod:=r.bx;
              end;
        'O' : Scramble:=true;
        'L' : LoopIt:=False;
        '?',
        'H' : HelpThem;
        'Z' : zoomThem:=false;
      end
    else begin
      modn:=paramstr(r.ax);
      fsplit(modn,d,e,g);
      r.bx:=modNameCnt;
      FindMods(modn);
      if (g='') and (r.bx=modNameCnt) then begin
        g:='.AMF';
        FindMods(d+e+g);
        g:='.MOD';
        FindMods(d+e+g);
        g:='.STM';
        FindMods(d+e+g);
      end;
    end;
  end;
  if modNameCnt=0 then Break('No files found!');
  if modNameCnt>1 then LoopIt:=false;
  randomize;
  if Scramble then
    for r.ax:=0 to modNameCnt*20 do begin
      r.cx:=random(modNameCnt)+1;
      r.dx:=random(modNameCnt)+1;
      s:=modNames[r.cx];
      modNames[r.cx]:=modNames[r.dx];
      modNames[r.dx]:=s;
    end;
  if tsInit<>0 then Break('Error initializing the player!');    { Initialize}
  pro:=false;                                                   { the player}
  if detectSBpro(@Scard)=0 then pro:=true else
  if detectSB(@Scard)<>0 then Break('No SB found!');         {  ...      }
  if pro then i:=mcpInitSoundDevice(SDI_SBPro,@Scard) else
              i:=mcpInitSoundDevice(SDI_SB,@Scard);
  If i<>0 then Break('Error initializing the SB!');
  playBuf:=malloc(4096+16+MCP_tableSize);
  with is do begin
    samplingRate:=srate;
    Options:=mcp_Quality;
    bufferSeg:=seg(playBuf^)+ofs(playBuf^) div 8;
    bufferLinear:=longint(bufferSeg)*16;
    bufferSize:=4096;
    reqSize:=1536;
  end;
  i:=mcpInit(is);
  i:=i or ampInit(0);
  tsAddRoutine(@ampInterrupt,ampTimer);
{  i:=i or mcpStartVoice;}
  if i<>0 then Break('Error initializing the player!');
  r.ax:=$13;
  intr($10,r);
  r.ax:=$1012;
  r.bx:=0;
  r.cx:=$100;
  r.es:=$a000;
  r.dx:=0;
  intr($10,r);
  ppp:=ptr($a000,0);
  UnpackPCJ(@HelpScreen,pp,ppp);
  for r.ax:=0 to BlkCnt-1 do
    GetBlock(HelpBlks[r.ax],BlkData[r.ax,0],BlkData[r.ax,1],BlkData[r.ax,2],BlkData[r.ax,3]);
  UnpackPCJ(@Piccy,pp,ppp);
  r.ax:=$1012;
  r.bx:=0;
  r.cx:=256;
  r.es:=seg(Pp);
  r.dx:=ofs(Pp);
  intr($10,r);
  Word2Blk('(C) 1992 Jussi Lahdenniemi',b);
  if odd(b.x) then r.bx:=2 else r.bx:=1;
  for r.ax:=r.bx to b.x do begin
    wr;
    zoom(b,160-r.ax div 2,125,r.ax+20);
    inc(r.ax)
  end;
  freemem(b.pic,b.siz);
  Word2Blk('and Otto Chrons (DSMI)',b);
  if odd(b.x) then r.bx:=2 else r.bx:=1;
  for r.ax:=r.bx to b.x do begin
    wr;
    zoom(b,160-r.ax div 2,144,r.ax);
    inc(r.ax);
  end;
  freemem(b.pic,b.siz);
  Word2Blk('Programmed in BP 7.0',b);
  if odd(b.x) then r.bx:=2 else r.bx:=1;
  for r.ax:=r.bx to b.x do begin
    wr;
    zoom(b,160-r.ax div 2,163,r.ax);
    inc(r.ax);
  end;
  freemem(b.pic,b.siz);

  screen:=scrTitle;
  First:=true;
  Repeat

    fsplit(modNames[modPointer],d,e,g);
    wr;
    if not First then begin
      Clrb(125*320+1,318);
      Clrb(144*320+1,318);
      Clrb(163*320+1,318);
    end;
    First:=false;
    Clrb(182*320+1,318);
    Word2Blk('Loading : '+e+g,b);
    if odd(b.x) then r.bx:=2 else r.bx:=1;
    for r.ax:=r.bx to b.x do begin
      wr;
      zoom(b,160-r.ax div 2,182,r.ax);
      inc(r.ax);
    end;
    freemem(b.pic,b.siz);
    module:=ampLoadModule(modNames[modPointer],LM_IML);
    if module=nil then begin
      Word2Blk('ERROR loading the module!',b);
      if odd(b.x) then r.bx:=2 else r.bx:=1;
      for r.ax:=r.bx to b.x do begin
        wr;
        zoom(b,160-r.ax div 2,125,r.ax);
        inc(r.ax);
      end;
      freemem(b.pic,b.siz);
      Word2Blk('Enter = try next, Esc=exit',b);
      if odd(b.x) then r.bx:=2 else r.bx:=1;
      for r.ax:=r.bx to b.x do begin
        wr;
        zoom(b,160-r.ax div 2,144,r.ax);
        inc(r.ax);
      end;
      freemem(b.pic,b.siz);
      while keypressed and (readkey<>#255) do;
      if readkey = #27 then Goto Quit;
      ch:='N';
      goto TryNext;
    end;

    i:=mcpOpenChannels(module^.channelCount,1,nil);
    i:=ampPlayModule(module^,byte(LoopIt)*PM_Loop);             { And PLAY! }

    r.ax:=mcpSetMasterVolume(masterVol);
    directVideo:=false;
    for r.ax:=0 to 3 do trackTime[r.ax]:=65535;
    r.ax:=0;
    cnt:=0;
    if screen=scrInfo then updateInfo;
    Repeat
{      ampPoll;}
      if prc[r.ax]>80 then dec(prc[r.ax],6) else dec(prc[r.ax],4);
      if prc[r.ax]<0 then prc[r.ax]:=0;
      r.bx:=module^.channelOrder[r.ax];
      trackData:=ampGetTrackData(r.bx);
      if trackData^.playtime<trackTime[r.bx] then prc[r.ax]:=Round((25/16)*trackData^.volume);
      if zoomThem then
      Word2Blk(Ascz2Str(module^.instrument^[trackData^.instrument].name),b);

      If DrawMethod=1 then begin
        r.cx:=round(318*(prc[r.ax]/100));
        wr;
        if (r.cx div 2>=0) and (r.cx div 2<158) then begin
          Clr((125+19*r.ax)*320+1,160-r.cx div 2);
          Clr((125+19*r.ax)*320+161+r.cx div 2,319-(161+r.cx div 2));
        end;
        if (r.cx>0) then
          if zoomThem then
          Zoom(b,160-r.cx div 2,125+19*r.ax,r.cx) else
          Clrg((125+19*r.ax)*320+160-r.cx div 2,r.cx);
      end else begin
        r.cx:=Trunc(prc[r.ax]*3.18);
        wr;
        if (r.cx<318) then Clr((125+19*r.ax)*320+1+r.cx,318-r.cx);
        if (r.cx>0) then if zoomThem then Zoom(b,1,125+19*r.ax,r.cx) else
                                          Clrg((125+19*r.ax)*320+1,r.cx);
      end;

      if zoomThem then
      Freemem(b.pic,b.siz);
      if trackdata^.playtime>0 then trackTime[r.bx]:=trackdata^.playtime;
      inc(r.ax);
      if r.ax=4 then r.ax:=0;
      ch:=' ';
      if keypressed then ch:=readkey;
      if keypressed then begin ch:=readkey;
        case ch of
          #59..#68   : masterVol:=round((ord(ch)-58)*(64/10));
          #80        : if scrDn and (screen=scrHelp) then begin
                         fillchar(mem[$a000:helpStart*320],(helpEnd-helpStart)*320,0);
                         inc(helpRow);
                         r.si:=helpStart;
                         r.di:=helpRow;
                         fillchar(mem[$a000:helpStart*320],(helpEnd-helpStart+1)*320,0);
                         while (r.si<helpEnd) and (r.di<hrCount) do begin
                           ppp:=helpBlks[hbOrder[r.di]];
                           putblock(ppp,0,r.si,0,byte(r.si+blockY(ppp)>helpEnd)*(r.si+blockY(ppp)-helpEnd));
                           inc(r.di);
                           inc(r.si,blockY(ppp)+helpSpace);
                         end;
                         scrDn:=not ((r.si<helpEnd) and (r.di=hrCount));
                         scrUp:=not (helpRow=0);
                         UpdScr;
                         ch:=' ';
                       end else ch:=' ';
          #72        : if scrUp and (screen=scrHelp) then begin
                         dec(helpRow);
                         r.si:=helpStart;
                         r.di:=helpRow;
                         fillchar(mem[$a000:helpStart*320],(helpEnd-helpStart+1)*320,0);
                         while (r.si<helpEnd) and (r.di<hrCount) do begin
                           ppp:=helpBlks[hbOrder[r.di]];
                           putblock(ppp,0,r.si,0,byte(r.si+blockY(ppp)>helpEnd)*(r.si+blockY(ppp)-helpEnd));
                           inc(r.di);
                           inc(r.si,blockY(ppp)+helpSpace);
                         end;
                         scrDn:=not ((r.si<helpEnd) and (r.di=hrCount));
                         scrUp:=not (helpRow=0);
                         UpdScr;
                       end;
          #75        : ampBreakPattern(-1);
          #77        : ampBreakPattern(1);
          #81        : if modNameCnt>1 then ch:='N';
          #73        : if modNameCnt>1 then ch:='P';
        end;
      end else
        case upcase(ch) of
          'H' : if screen<>scrHelp then begin
                  fillchar(mem[$a000:0],123*320,0);
                  putblock(HelpBlks[4],160-Blockx(HelpBlks[4]) div 2,0,0,0);
                  helpRow:=0;
                  r.si:=helpStart;
                  r.di:=helpRow;
                  fillchar(mem[$a000:helpStart*320],(helpEnd-helpStart+1)*320,0);
                  while (r.si<helpEnd) and (r.di<hrCount) do begin
                    ppp:=helpBlks[hbOrder[r.di]];
                    putblock(ppp,0,r.si,0,byte(r.si+blockY(ppp)>helpEnd)*(r.si+blockY(ppp)-helpEnd));
                    inc(r.di);
                    inc(r.si,blockY(ppp)+helpSpace);
                  end;
                  scrDn:=not ((r.si<helpEnd) and (r.di=hrCount));
                  scrUp:=not (helpRow=0);
                  UpdScr;
                  screen:=scrHelp;
                end;
          'T' : if screen<>scrTitle then begin
                  ppp:=ptr($a000,0);
                  UnpackPCJ(@Piccy,pp,ppp);
                  screen:=scrTitle;
                end;
          'D' : begin
                  rg.ax:=3;
                  intr($10,rg);
                  setMemTop(HeapPtr);
                  swapvectors;
                  exec(getenv('COMSPEC'),'');
                  swapvectors;
                  setMemTop(HeapEnd);
                  rg.ax:=$13;
                  intr($10,rg);
                  rg.ax:=$1012;
                  rg.bx:=0;
                  rg.cx:=$100;
                  rg.es:=$a000;
                  rg.dx:=0;
                  intr($10,rg);
                  ppp:=ptr($a000,0);
                  unpackPCJ(@Piccy,pp,ppp);
                  rg.ax:=$1012;
                  rg.bx:=0;
                  rg.cx:=$100;
                  rg.es:=seg(pp);
                  rg.dx:=ofs(pp);
                  intr($10,rg);
                  screen:=scrTitle;
                end;
          'B' : DrawMethod:=DrawMethod xor 1;
          'I' : if screen<>scrInfo then begin
                  ppp:=ptr($a000,0);
                  unpackPCJ(@InfoScreen,pp,ppp);
                  updateInfo;
                  screen:=scrInfo;
                end;
          'P' : begin
                  if (ampGetModuleStatus and MD_Paused)=0 then
                     i:=ampPauseModule else i:=ampResumeModule;
                  if screen=scrInfo then updateInfo;
                  ch:=' ';
                end;
          'N' : ch:=' ';
          'Z' : zoomThem:=not zoomThem;
        end;
      if (modNameCnt>1) and (ampGetPattern=module^.patternCount-1) then
        i:=mcpSetMasterVolume((64-ampGetRow)*masterVol shr 6) else
        i:=mcpSetMasterVolume(MasterVol);
      if (upcase(ch) in ['N','P']) and (modNameCnt=1) then ch:=' ';
      if (ampGetModuleStatus and MD_Playing)=0 then
        ch:=char(27+byte(modNameCnt>1)*(ord('N')-27));
    Until ch in [#27,'n','N','p','P'];
    if (ch<>#27) and ((ampGetModuleStatus and MD_Playing)>0) then i:=ampStopModule;
    if (ch<>#27) then begin
      ampFreeModule(module);
      dispose(module);
    end;
    TryNext:
    if (upcase(ch)='N') and (modNameCnt>1) then begin
      inc(modPointer);
      if modPointer>modNameCnt then modPointer:=1;
    end else if (upcase(ch)='P') and (modNameCnt>1) then begin
      dec(modPointer);
      if modPointer<1 then modPointer:=modNameCnt;
    end;
  Until ch=#27;
  Quit:
  port[$3c8]:=0;
  for r.ax:=255 downto 0 do begin
    wr;
    r.bx:=mcpSetMasterVolume(Round((r.ax/256)*masterVol));
    port[$3c9]:=0;
    port[$3c9]:=0;
    port[$3c9]:=0;
  end;

  ampClose;                                   { Deinitialization }
  mcpClose;
  tsClose;

  i:=r.es;
  r.ax:=3;
  intr($10,r);
end.
