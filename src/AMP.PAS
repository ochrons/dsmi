(****************************************************************************

                                   AMP.PAS
                                   -------

                          (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for AMP.
Original C header by Otto Chrons

****************************************************************************)

Unit AMP;

{$A+,B-,D+,E+,F+,G+,I+,L+,N-,O-,R-,S+,V+,X-,M 16384,0,655360}

Interface
Uses MCP,CDI;

Const cmdInstr           = $80;
      cmdTempo           = $81;
      cmdVolume          = $82;
      cmdVolumeAbs       = $83;
      cmdBender          = $84;
      cmdBenderAbs       = $85;
      cmdBenderTo        = $86;
      cmdTremolo         = $87;
      cmdArpeggio        = $88;
      cmdVibrato         = $89;
      cmdToneVol         = $8A;
      cmdVibrVol         = $8B;
      cmdBreak           = $8C;
      cmdGoto            = $8D;
      cmdSync            = $8E;
      cmdRetrig          = $8F;
      cmdOffset          = $90;
      cmdFinevol         = $91;
      cmdFinetune        = $92;
      cmdNoteDelay       = $93;
      cmdNoteCut         = $94;
      cmdExtTempo        = $95;
      cmdExtraFineBender = $96;
      cmdPan             = $97;

      Crit_Size          = 256;

      MOD_None           = 0;
      MOD_MOD            = 1;
      MOD_STM            = 2;
      MOD_AMF            = 3;
      MOD_15             = 4;
      MOD_TREK           = 5;
      MOD_S3M            = 6;
      MOD_669            = 7;
      MOD_MTM            = 8;
      MOD_FAR            = 9;
      MOD_MULTI          = 10;

      MERR_NONE          = 0;
      MERR_MEMORY        = -1;
      MERR_FILE          = -2;
      MERR_TYPE          = -3;
      MERR_CORRUPT       = 1;

      LM_IML             = 1;
      LM_OLDTEMPO        = 2;

      PM_Loop            = 1;

      TR_Muted           = 2;

      MD_Playing         = 1;
      MD_Paused          = 2;

      Max_Tracks         = 32;

      AMP_Timer          = 1193180 div 100;

      PAN_Left           = -63;
      PAN_Right          = 63;
      PAN_Middle         = 0;
      PAN_Surround       = 100;


Type  PNote            = ^TNote;
      TNote            = Record
                           TimeSig          : Byte;
                           Note             : Byte;
                           Velocity         : Byte;
                         End;

      PCommand         = ^TCommand;
      TCommand         = Record
                           timeSig          : Byte;
                           command          : Byte;
                           value            : Byte;
                         End;

      PTrack           = ^TTrack;
      TTrack           = Record
                           Size             : Word;
                           trkType          : Byte;
                           Notes            : Array[0..0] of TNote;
                         End;

      PPattern         = ^TPattern;
      TPattern         = Record
                           Length           : Integer;
                           Tracks           : Array[0..Max_Tracks-1] of PTrack;
                         end;

      PInstrument      = ^TInstrument;
      TInstrument      = Record
                           insType          : Byte;
                           Name             : Array[0..31] of char;
                           Filename         : Array[0..12] of char;
                           Sample           : Pointer;
                           Size             : Longint;
                           Rate             : Word;
                           Volume           : Byte;
                           Loopstart,
                           Loopend          : Longint;
                         End;

      AMTracks         = Array[0..15999] of PTrack;
      AMInstr          = Array[0..(65520 div sizeof(TInstrument)-1)] of TInstrument;
      AMPattern        = Array[0..(65520 div sizeof(TPattern)-1)] of TPattern;

      PModule          = ^TModule;
      TModule          = Record
                           modType          : Byte;
                           Size             : Longint;
                           Filesize         : Longint;
                           Name             : Array[0..31] of char;
                           ChannelCount     : Byte;
                           ChannelPanning   : Array[0..Max_Tracks-1] of shortint;
                           InstrumentCount  : Byte;
                           Instruments      : ^AMInstr;
                           PatternCount     : Byte;
                           Patterns         : ^AMPattern;
                           TrackCount       : Word;
                           Tracks           : ^AMTracks;
                           Tempo            : Byte;
                           Speed            : Byte;
                         End;

      PNoteInfo        = ^TNoteInfo;
      TNoteInfo        = Record
                           Note             : Shortint;
                           Instrument       : Shortint;
                           Velocity         : Shortint;
                           Played           : Word;
                         End;

      PCmdInfo         = ^TCmdInfo;
      TCmdInfo         = Record
                           Command          : Word;
                           Value            : Word;
                         End;

      PTrackData       = ^TTrackData;
      TTrackData       = Record
                           Status           : Word;
                           Note             : Byte;
                           Instrument       : Byte;
                           Volume           : Byte;
                           Playtime         : Word;
                           Command          : Byte;
                           CmdValue         : Byte;
                           Panning          : Shortint;
                         End;

      S_MODULE         = Record
                           modType          : byte;
                           size             : longint;
                           filesize         : longint;
                           mname            : array[0..31] of char;
                           channelCount     : byte;
                           channelOrder     : byte;
                           instrumentCount  : byte;
                           instruments      : longint;
                           patternCount     : byte;
                           patterns         : longint;
                           trackCount       : word;
                           tracks           : longint;
                         end;

      S_TRACKDATA      = Record
                           status           : word;
                           note             : byte;
                           instrument       : byte;
                           velocity         : byte;
                           playtime         : word;
                           command          : byte;
                           cmdvalue         : byte;
                         end;

      S_PLAYINFO       = Record
                           initOptions      : word;
                           status           : byte;
                           options          : word;
                           firstPattern     : byte;
                           lastPattern      : byte;
                           pattern          : byte;
                           tracks           : byte;
                           ticks            : word;
                           row              : word;
                           cmdcount         : byte;
                           patterndata      : longint;
                           instrdata        : longint;
                           tempo            : byte;
                           exttempo         : byte;
                           tempovalue       : byte;
                           sync             : byte;
                           break            : byte;
                           timerValue       : word;
                           timerCount       : word;
                           channelCount     : word;
                           channelOrder     : array[0..max_Tracks-1] of byte;
                         end;

      S_NOTEINFO       = Record
                           note             : byte;
                           instrument       : byte;
                           velocity         : byte;
                           played           : word;
                           noteold          : word;
                         end;

      S_CMDINFO        = Record
                           command          : byte;
                           value            : byte;
                           bendervalue      : word;
                           benderadd        : byte;
                           bendercmd        : byte;
                           arpeggio1        : longint;
                           arpeggio2        : longint;
                           arpeggio3        : longint;
                           arpeggioptr      : byte;
                           vibratopos       : byte;
                           vibratocmd       : byte;
                           tremolocmd       : byte;
                           tremolospeed     : byte;
                           tremolovalue     : byte;
                           tremolopos       : byte;
                           offsetvalue      : byte;
                         end;

      S_TRACKINFO      = Record
                           track            : longint;
                           pos              : word;
                           status           : word;
                           note             : S_NOTEINFO;
                           cmd              : S_CMDINFO;
                         end;

      S_SAMPLEINFO     = Record
                           sample           : longint;
                           length           : word;
                           loopstart        : word;
                           loopend          : word;
                           rate             : word;
                           volume           : byte;
                           mode             : byte;
                           orgrate          : word;
                         end;

Var ModuleError        : Integer;

Var _curModule       : TModule;
    trackdata        : S_TRACKDATA;
    moduleinfo       : S_PLAYINFO;
    tracks           : Array[0..Max_Tracks-1] of S_TRACKINFO;
    samples	         : Array[0..Max_Tracks-1] of S_SAMPLEINFO;

Function  ampInit(options:longint):integer;
Procedure ampClose;
Function  ampPlayModule(module:PModule;opt:longint):integer;
Function  ampPlayMultiplePatterns(module:PModule;startp,endp,opt:longint):integer;
Function  ampPlayPattern(module:PModule;pat,opt:longint):integer;
Function  ampStopModule:integer;
Function  ampPauseModule:integer;
Function  ampResumeModule:integer;
Function  ampGetModuleStatus:integer;
Function  ampMuteTrack(track:longint):integer;
Function  ampUnmuteTrack(track:longint):integer;
Function  ampGetTrackStatus(track:longint):integer;
Function  ampGetTrackData(track:longint):PTrackdata;
Function  ampGetPattern:integer;
Function  ampGetRow:integer;
Function  ampGetSync:integer;
Function  ampGetTempo:word;
Procedure ampSetTempo(tempo:longint);
Procedure ampSetPanning(track,direction:longint);
Procedure ampSetMasterVolume(track,volume:longint);
Procedure ampPlayRow;
Procedure ampBreakPattern(direction:longint);
Function  ampGetBufferDelta:longint;

Procedure ampInterrupt; interrupt;
Procedure ampPoll;

Implementation
{$IFDEF USE_EMS}
uses mcpems;
{$ELSE}
uses mcpreala;
{$ENDIF}

{$L AMPlayer.OBJ}

Function  ampInit(options:longint):integer; external;
Procedure ampClose; external;
Function  ampPlayModule(module:PModule;opt:longint):integer; external;
Function  ampPlayMultiplePatterns(module:PModule;startp,endp,opt:longint):integer; external;
Function  ampPlayPattern(module:PModule;pat,opt:longint):integer; external;
Function  ampStopModule:integer; external;
Function  ampPauseModule:integer; external;
Function  ampResumeModule:integer; external;
Function  ampGetModuleStatus:integer; external;
Function  ampMuteTrack(track:longint):integer; external;
Function  ampUnmuteTrack(track:longint):integer; external;
Function  ampGetTrackStatus(track:longint):integer; external;
Function  ampGetTrackData(track:longint):PTrackdata; external;
Function  ampGetPattern:integer; external;
Function  ampGetRow:integer; external;
Function  ampGetSync:integer; external;
Function  ampGetTempo:word; external;
Procedure ampSetTempo(tempo:longint); external;
Procedure ampSetPanning(track,direction:longint); external;
Procedure ampSetMasterVolume(track,volume:longint); external;
Procedure ampPlayRow; external;
Procedure ampBreakPattern(direction:longint); external;
Function  ampGetBufferDelta:longint; external;

Procedure ampInterrupt; external;
Procedure ampPoll; external;

End.

