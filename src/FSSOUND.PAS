Unit FSSound;
{$DEFINE USE_EMS}

{
        Jussi Lahdenniemi                  Otto Chrons
        Rautia                             Vaajakatu 5 K 199
        FIN-36420 Sahalahti                FIN-33720 Tampere
        FINLAND                            FINLAND

        Phone: (+358)-31-3763612           Phone: (+358)-31-3171347
        Internet: jlahd@clinet.fi          Internet: otto.chrons@cc.tut.fi
        Fidonet:  2:222/105.7
}

Interface

Uses AMP,           { Advanced Module Player                               }
     Loaders,       { Contains the freeing procedure                       }
     MCP,           { Multi-Channel Player                                 }
     CDI,           { Channel Distribution Interface                       }
     DET_SB,        { Detection Routines - Sound Blaster family            }
     DET_PAS,       { Detection Routines - Pro Audio Spectrum family       }
     S3MLOAD,       { Screamtracker 3 loading routines                     }
     VDS,           { Virtual DMA Specification                            }
     SDI__SB,       { Sound Device Interface - Sound Blaster               }
     SDI__SB16,     { Sound Device Interface - Sound Blaster 16            }
     SDI__PAS,      { Sound Device Interface - Pro Audio Spectrum          }
     CSupport,      { stupid moronic routines that 'mimic' c routines      }
     timeserv,      { Timer Service                                        }
     CRT,           { for delays.. man I wish I could just write a q&d one }
     FSBasics,      { configuration information required                   }
     EMHM;          { EMS Header Manager that I dont know how to use yet   }

Const
 MODE_Mono    : Boolean = False;       { Make true if you dont want stereo }
 MODE_Quality : Boolean = False;       { Make true if its an SB1.0/1.5/2.0 }
 SoundOK      : Boolean = False;       { Make true after initialization OK }
 P_Left       = PAN_LEFT;
 P_Right      = PAN_RIGHT;
 P_Middle     = PAN_MIDDLE;
 MinHeap      = 256;                   { Minimum EMS in Kilobytes allowed  }
 MaxHeap      = 1024;                  { Maximum EMS in Kilobytes allowed  }

     { error codes }
 I_Soundcard      = 1;      { no sound card found                      }
 I_NotSupported   = 2;      { sound card found but not supported by FS }
 I_ampInitFailure = 3;      { amp could not initialize                 }
 I_mcpInitFailure = 4;      { mcp could not initialize                 }
 MaxChannels = 4;
 CurChannel : Byte = 1;

Var SCh : Array[1..MaxChannels] of Byte;
    Sounds,
    Music      : PModule;
    dds        : TDDS;
    Var SoundChannels : Integer;


Function InitDSMI( rate, buffer : LongInt; Scard : PSoundcard ) : Byte;
Function ScardName( id : Integer ) : String;
Function LoadRaw( fn : string; var SInfo:TSampleinfo; emsOK : Boolean ) : Integer;
Procedure PlaySound( N : Integer; Panning, Vol : Integer );
Procedure PlaySample( SInfo : TSampleInfo; Panning, Vol : Integer );
Procedure FreeSample( Var SInfo : PSampleInfo; emsOk : Boolean );
Procedure SetVol( SChannel, EChannel, Vol : Integer );
Procedure LoadPlayModule( Var M : PModule; fn : String;  Vol : Integer;
                          Play : Boolean );
{
Function GetVol( SChannel : Integer ) : Integer;
Procedure FadeLtoR;
Procedure FadeRtoL;
Procedure FadetoM;
}

Implementation


Procedure LoadPlayModule( Var M : PModule; fn : String;  Vol : Integer;
                          Play : Boolean );
Var X : Integer;
Begin
 If M <> Nil then ampFreeModule( M );
 M := ampLoadS3M( fn, LM_IML );
 cdiSetupChannels(0, M^.ChannelCount + SoundChannels, Nil);
 For X := 1 to MaxChannels do
  If X < SoundChannels then  SCh[x] := M^.ChannelCount + (X-1)
                        else SCh[x] := M^.ChannelCount;
 If Play then
  Begin
   ampPlayModule( M, PM_LOOP );
   SetVol( M^.ChannelCount, M^.ChannelCount + SoundChannels, 64 );
   SetVol( 0, M^.ChannelCount-1, Vol );
  End;
End;


Function InitDSMI( rate, buffer : longint; Scard : PSoundcard ) : Byte;
var S       : Word;
    sdi     : TSDI_Init;
    Temp    : Pointer;
    fError  : Byte;
    mcpInfo : TMCPStruct;
begin
  FError := 0;
  If (DetectPAS(Scard) <> 0) then
   If (DetectSB(Scard) <> 0) then fError := I_Soundcard else
    Begin
     Case Scard^.ID of
      ID_SB    : sdi := SDI_SB;        { Sound Driver Interface Procedure }
      ID_SBPro : sdi := SDI_SBPro;
      ID_SB16  : Begin
                   sdi := SDI_SB16;
                   If MODE_Mono then Scard^.stereo := FALSE;
                 End;
      ID_PAS,
      ID_PASplus,
      ID_PAS16 : begin
                   sdi := SDI_PAS;
                   if MODE_Mono then Scard^.stereo := FALSE;
                 end;
      Else Begin
            fError := I_NotSupported;
           End
       End
    End;

 If (fError = 0) then
  Begin
   mcpInitSoundDevice(sdi, Scard);
   mcpInfo.Options := 0;
   S := buffer * 2 + MCP_Tablesize + 16;
   If MODE_Quality then
       Begin
         mcpInfo.Options := mcpInfo.Options OR MCP_Quality;
         Inc( S, MCP_Qualitysize );
       End;
    Temp := malloc(s);
    If Temp = Nil then Halt(203);
    mcpInfo.bufferSeg := Seg(Temp^) + Ofs(Temp^) div 16 + 1;
    DDS.size    := buffer;                          { set up digital access }
    DDS.segment := mcpInfo.bufferSeg;
    DDS.offset  := 0;
    If (vdsLockDMA(@dds) = 0) then
      Begin
        mcpInfo.bufferPhysical := DDS.address;
        vdsDisableDMATranslation(Scard^.dmaChannel);
      End else mcpInfo.bufferPhysical := longint(mcpInfo.bufferSeg) * 16;
      mcpInfo.bufferSize   := buffer * 2;
      mcpInfo.reqSize      := buffer;
      mcpInfo.samplingRate := rate;
    if (mcpInit(@mcpInfo) <> 0) then fError := I_mcpInitFailure else
     Begin
      atexit(@mcpClose);
      cdiInit;
      cdiRegister(@CDI_MCP,0,31);
      tsInit;
      atexit(@tsClose);
      if (ampInit(0) <> 0) then fError := I_ampInitFailure else
       Begin
        atexit(@ampClose);
        tsAddRoutine(@ampInterrupt,AMP_Timer);
       End;
     End;
   End;
  InitDSMI := fError;
end;

Procedure InitSound;
Var fError  : Integer;
    SC      : TSoundCard;
Begin
 Music := Nil;
 If (paramstr(1) <> '-nosound') then begin
 fError := InitDSMI(25000, 2048, @SC);
 If (fError <> 0) then
  Begin
   Case fError of
      I_NotSupported : Write('þ Found Unsupported Sound Device');
    I_ampInitFailure : Write('þ ampInitFailure');
    I_mcpInitFailure : Write('þ mcpInitFailure');
      End;
   Writeln(' - Execution Continuing Without Sound');
   SoundOK := FALSE;
  End else
   Begin
    Writeln('þ Initializing ', ScardName(SC.ID) );
    SoundOK := TRUE;
    Sounds := ampLoadS3M( 'SOUNDLIB.S3M', LM_IML );
    mcpStartVoice;
   End;
  End;
End;

Function ScardName( id : integer ) : String;
Begin
 Case ID of
  ID_SB    : ScardName := 'Sound Blaster';
  ID_SBPro : ScardName := 'Sound Blaster Pro';
  ID_SB16  : ScardName := 'Sound Blaster 16';
    ID_PAS : ScardName := 'Pro Audio Spectrum';
ID_PASplus : ScardName := 'Pro Audio Spectrum Plus';
  ID_PAS16 : ScardName := 'Pro Audio Spectrum 16';
  Else Scardname := 'Unsupported Sound Device';
 End
End;

Function LoadRaw( fn : string; var SInfo:TSampleinfo; emsOK : Boolean ) : Integer;
var f : file;
    a : integer;
    FSize : longint;
    {$IFNDEF DPMI}
    e : TEMSH;
    {$ENDIF}
begin
  fillchar( SInfo, Sizeof(TSampleinfo), 0 );    { Clear SInfo }
  {$I-}                                          { Open sample file }
  Assign(f, fn);
  Reset(f, 1);
  LoadRaw := -1;
  if (IOresult = 0) then
   Begin
    FSize := FileSize(f);                        { Get the length of the file }
    if (FSize > 65520) then FSize := 65520;

    { Can we use EMS? }
    {$IFNDEF DPMI}                  (* I'm leaving this alone until we get *)
    e := 0;                         (* BP7.0 and I understand DPMI or EMS  *)
    if emsOK then begin             (*                        - herb       *)
      e:=emsAlloc(fsize);
      if e>0 then begin
        { Map into page frame }
        sinfo.sample:=emsLock(e,0,fsize);
        sinfo.sampleID:=e;
      end;
    end;
    if e=0 then begin
    {$ENDIF}
      sinfo.sample:=malloc(fsize);
      if sinfo.sample=nil then exit;
    {$IFNDEF DPMI}
    end;
    {$ENDIF}

    BlockRead(f, SInfo.Sample^, FSize);            { Read sample data }
    SInfo.length    := FSize;                      { Fill the other fields }
    SInfo.loopstart := 0;                          { change file structure }
    SInfo.loopend   := 0;

    if sinfo.sampleID<>0 then                      { Was it loaded into EMS? }
     Begin                                         { Download with sampleID }
      cdiDownloadSample(0, SInfo.Sample, Pointer(SInfo.sampleID), FSize);
      SInfo.Sample := Pointer(SInfo.sampleID);   { Download with pointer }
     End else cdiDownloadSample(0,sinfo.sample,sinfo.sample, FSize);
    Close(f);
    LoadRaw := 0;
   End
 {$I+}
End;

Procedure FreeSample( Var SInfo : PSampleInfo; emsOk : Boolean );
    {$IFNDEF DPMI}
var  e : TEMSH;
    {$ENDIF}
Begin
   {$IFNDEF DPMI}
   if sinfo^.sampleID <> 0 then emsFree(sinfo^.sampleID);
   {$ELSE}
   dispose(sinfo^.sample);
   {$ENDIF}
   dispose(sinfo);
End;

Procedure PlaySample( SInfo : TSampleInfo; Panning, Vol : Integer );
Var Channel, X : Integer;
Begin
 If Panning = -1 then Panning := PAN_MIDDLE;
 If (SoundOK) then
  Begin
   Channel := Music^.ChannelCount;
   For X := Music^.ChannelCount+1 to (Music^.ChannelCount + SoundChannels) do
    If (cdiGetVolume(X) < cdiGetVolume(X-1)) then Channel := X;
   cdiSetInstrument(Channel, @Sinfo);
   cdiPlayNote(Channel, 11025, Vol);       { mid-range note = normalcy }
   cdiSetPanning(Channel, Panning);
  End;
End;

Procedure PlaySound( N : Integer; Panning, Vol : Integer );
Var Channel, X : Integer;
    FakeSample : TSampleInfo;
Begin
 If Panning = -1 then Panning := PAN_MIDDLE;
 If (SoundOK) then
  Begin
   If N > Sounds^.InstrumentCount then N := Sounds^.InstrumentCount;
   Channel := (Music^.ChannelCount) + (CurChannel mod SoundChannels);
   Inc(CurChannel);
{   Writeln('Playing ', N, ' on ', Channel ); }
   With Sounds^.Instruments^[N] do
    Begin
     FakeSample.Sample := Sample;
     FakeSample.Length := Size;
     FakeSample.LoopStart := LoopStart;
     FakeSample.LoopEnd := LoopEnd;
     FakeSample.Mode := 0;
     FakeSample.SampleID := 0;
    End;
   cdiSetInstrument(Channel, @FakeSample);
   cdiPlayNote(Channel, {Sounds^.Instruments^[N].Rate} 11025, Vol);
   cdiSetPanning(Channel, Panning);
  End;
End;

Procedure SetVol( SChannel, EChannel, Vol : Integer );
Var X, Y : Integer;
Begin
  For Y := SChannel to EChannel do cdiSetMasterVolume(Y, Vol);
End;

Procedure InitEMHM;
Var Err : Integer;
Begin
 Write('þ Initializing Extended Memory Heap Manager(tm): ');
 atexit(@emsClose);
 Err := emsInit(MinHeap, MaxHeap);
 If Err = EMS_ERROR then
  Begin
   Writeln('EMHM Error: No Extended Memory Manager installed!');
   Halt(0);
  End else If Err = EMS_MEMORY then Halt(10);
 Writeln('Successful');
 Writeln(' x EMS Heap free: ', emsHeapFree * 1024 );
End;

Begin
 SoundChannels := KC.Channels;
 InitEMHM;
 InitSound;
 LoadPlayModule( Music, 'FUTURE2.S3M', KC.MusicVolume, TRUE );
End.
