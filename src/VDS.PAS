Unit vds; { (C) 1993 Jussi Lahdenniemi,
            original C-version (C) 1993 Otto Chrons

            Virtual DMA services }

Interface

type PDDS           = ^TDDS;
     TDDS           = record
       size         : longint;
       offset       : longint;
       segment      : word;
       ID           : word;
       address      : longint;
     end;

Function vdsInit:integer;
Function vdsEnableDMATranslation(DMAchannel:word):Integer;
Function vdsDisableDMATranslation(DMAchannel:word):Integer;
Function vdsLockDMA(dds:PDDS):Integer;
Function vdsUnlockDMA(dds:PDDS):Integer;

Implementation

Function vdsInit:integer; external;
Function vdsEnableDMATranslation(DMAchannel:word):Integer; external;
Function vdsDisableDMATranslation(DMAchannel:word):Integer; external;
Function vdsLockDMA(dds:PDDS):Integer; external;
Function vdsUnlockDMA(dds:PDDS):Integer; external;

{$L VDS.OBJ}

end.
