(****************************************************************************

                                   DSMI.INC
                                   --------

                          (C) 1993 Jussi Lahdenniemi

Include file with a Uses-clause that includes all the necessary units of DSMI

****************************************************************************)

Uses DSMI,MCP,GUS,AMP,CDI,Timeserv,Mixer,VDS,
     SDI__SB,SDI__PAS,SDI__SB16,SDI__ARIA,SDI__WSS,
     Det_SB,Det_PAS,Det_ARIA,DetGUS,
     LoadM,Loaders,STMload,MODload,AMFload,MTMload,FARload,
     Csupport

{$IFDEF DPMI}
,dpmiAPI
{$ELSE}
,SDI__DAC
{$ENDIF}

{$IFDEF USE_EMS}
,mcpems,emhm
{$ELSE}
,mcpreala
{$ENDIF}
