(****************************************************************************

                                 TIMESERV.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for Timer service.
Original C header by Otto Chrons

****************************************************************************)

Unit TimeServ;

Interface

Function  tsInit:Integer;
Procedure tsClose;
Function  tsAddRoutine(Func:Pointer;Time:longint):Integer;
Function  tsRemoveRoutine(tag:longint):Integer;
Function  tsChangeRoutine(tag:longint;time:longint):Integer;
Procedure tsSetTimerRate(rate:longint);
Function  tsGetTimerRate:word;

Const tsInited : byte = 0;

Implementation

{$L TimeServ.Obj}

Function  tsInit:Integer; External;
Procedure tsClose; External;
Function  tsAddRoutine(Func:Pointer;Time:longint):Integer; External;
Function  tsRemoveRoutine(tag:longint):Integer; External;
Function  tsChangeRoutine(tag:longint;time:longint):Integer; External;
Procedure tsSetTimerRate(rate:longint); External;
Function  tsGetTimerRate:word; External;

End.
