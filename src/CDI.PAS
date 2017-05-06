{ -------------------------------------------------------------------------- }
{                                                                            }
{                                  CDI.PAS                                   }
{                                  -------                                   }
{                                                                            }
{                         (C) 1993 Jussi Lahdenniemi                         }
{         Original C file (C) 1993 Otto Chrons                               }
{                                                                            }
{ Channel Distributor unit file                                              }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit cdi;

interface

type    PCDIdevice = ^TCDIdevice;
        TCDIdevice = Record
          setsample, playsample, setvolume, setfrequency, setlinearrate,
          setposition, setpanning, setmastervolume, mutechannel,
          unmutechannel, stopchannel, muteall, unmuteall, poll, getdelta,
          download, unload, unloadall, getvolume, getfrequency,
          getposition, getpan, getsample, setupch, getchannelstatus
                   : pointer;
        end;

var     cdiStatus  : word;

Function  cdiInit:integer;
Function  cdiRegister(cdi:PCDIdevice;firstch,lastch:longint):integer;
Procedure cdiClose;
Procedure cdiSetMasterVolume(channel:longint;volume:longint);
Procedure cdiSetInstrument(channel:longint;inst:Pointer);
Procedure cdiPlayNote(channel:longint;freq:longint;volume:longint);
Procedure cdiStopNote(channel:longint);
Procedure cdiSetVolume(channel:longint;volume:longint);
Procedure cdiSetFrequency(channel:longint;freq:longint);
Procedure cdiSetLinear(channel:longint;pos:longint);
Procedure cdiSetPosition(channel:longint;pan:longint);
Procedure cdiSetPanning(channel,volume:longint);
Procedure cdiMute(channel:longint);
Procedure cdiUnmute(channel:longint);
Procedure cdiMuteAll(channel:longint);
Procedure cdiUnmuteAll(channel:longint);
Function  cdiPoll(channel:longint):integer;
Function  cdiGetDelta(channel:longint):longint;
Procedure cdiDownloadSample(channel:longint;sample,sampletag:pointer;len:longint);
Procedure cdiUnloadSample(channel:longint);
Procedure cdiUnloadAll(channel:longint);
Function  cdiGetVolume(channel:longint):word;
Function  cdiGetFrequency(channel:longint):longint;
Function  cdiGetPosition(channel:longint):longint;
Function  cdiGetPanning(channel:longint):integer;
Function  cdiGetInstrument(channel:longint):pointer;
Function  cdiGetChannelStatus(channel:longint):integer;
Function  cdiSetupChannels(channel,count:longint;volTable:pointer):integer;

implementation

Function  cdiInit:integer; external;
Function  cdiRegister(cdi:PCDIdevice;firstch,lastch:longint):integer; external;
Procedure cdiClose; external;
Procedure cdiSetMasterVolume(channel:longint;volume:longint); external;
Procedure cdiSetInstrument(channel:longint;inst:Pointer); external;
Procedure cdiPlayNote(channel:longint;freq:longint;volume:longint); external;
Procedure cdiStopNote(channel:longint); external;
Procedure cdiSetVolume(channel:longint;volume:longint); external;
Procedure cdiSetFrequency(channel:longint;freq:longint); external;
Procedure cdiSetLinear(channel:longint;pos:longint); external;
Procedure cdiSetPosition(channel:longint;pan:longint); external;
Procedure cdiSetPanning(channel,volume:longint); external;
Procedure cdiMute(channel:longint); external;
Procedure cdiUnmute(channel:longint); external;
Procedure cdiMuteAll(channel:longint); external;
Procedure cdiUnmuteAll(channel:longint); external;
Function  cdiPoll(channel:longint):integer; external;
Function  cdiGetDelta(channel:longint):longint; external;
Procedure cdiDownloadSample(channel:longint;sample,sampletag:pointer;len:longint); external;
Procedure cdiUnloadSample(channel:longint); external;
Procedure cdiUnloadAll(channel:longint); external;
Function  cdiGetVolume(channel:longint):word; external;
Function  cdiGetFrequency(channel:longint):longint; external;
Function  cdiGetPosition(channel:longint):longint; external;
Function  cdiGetPanning(channel:longint):integer; external;
Function  cdiGetInstrument(channel:longint):pointer; external;
Function  cdiGetChannelStatus(channel:longint):integer; external;
Function  cdiSetupChannels(channel,count:longint;volTable:pointer):integer; external;

{$L cdi.obj}

end.
