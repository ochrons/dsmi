(****************************************************************************

                                    MIXER.PAS
                                    ---------

                           (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for mixer routines.
Original C header by Otto Chrons

****************************************************************************)

Unit mixer;

Interface

Procedure mixerinit(t:byte;ioBase:word);
Procedure mixerset(func:integer;value:byte);
Function  mixerget(func:integer):byte;

Const   MIXER_SBPRO     = 1;

	MIX_LEFT	= $40;
	MIX_RIGHT	= $80;
	MIX_BOTH	= MIX_LEFT OR MIX_RIGHT;

	MIX_IN_MIC	= 1;
	MIX_IN_CD	= 2;
	MIX_IN_LINE	= 3;
	MIX_FILTERHIGH	= $40;

	MIX_FM_NORMAL	= 0;
	MIX_FM_LEFT	= 1;
	MIX_FM_RIGHT	= 2;
	MIX_FM_MUTE	= MIX_FM_RIGHT OR MIX_FM_LEFT;

	MIX_RESET	= 0;
	MIX_MASTERVOL	= 1;
	MIX_DACVOL 	= 2;
	MIX_FMVOL 	= 3;
	MIX_CDVOL	= 4;
	MIX_MICVOL	= 5;
	MIX_LINEVOL	= 6;
	MIX_STEREO	= 7;
	MIX_FILTEROUT	= 8;
	MIX_FILTERIN	= 9;
	MIX_INPUTLINE	= 10;
	MIX_FM_MODE	= 11;

	MIX_LASTFUNCT	= MIX_FM_MODE;

Implementation

Procedure mixerInit(t:byte;ioBase:word); External;
Procedure mixerSet(func:integer;value:byte); External;
Function  mixerGet(func:integer):byte; External;

{$L MIXER.OBJ}

End.
