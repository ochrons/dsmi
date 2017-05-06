;/************************************************************************
; *
; *     File        : CDI.INC
; *
; *     Description : Include file for Channel Distributor
; *
; *     Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************/

STRUC CDIDEVICE
      setsample         DD ?
      playsample        DD ?
      setvolume         DD ?
      setfrequency      DD ?
      setlinearrate     DD ?
      setposition       DD ?
      setpanning        DD ?
      setmastervolume   DD ?
      mutechannel       DD ?
      unmutechannel     DD ?
      stopchannel       DD ?
      muteall           DD ?
      unmuteall         DD ?
      poll              DD ?
      getdelta          DD ?
      download          DD ?
      unload            DD ?
      unloadall         DD ?
      getvolume         DD ?
      getfrequency      DD ?
      getposition       DD ?
      getpan            DD ?
      getsample         DD ?
      setupch           DD ?
      getchannelstatus  DD ?
ENDS

        CGLOBAL cdiInit:_FAR, cdiRegister:_FAR, cdiClose:_FAR

        CGLOBAL cdiSetInstrument:_FAR, cdiPlayNote:_FAR, cdiStopNote:_FAR
        CGLOBAL cdiSetVolume:_FAR, cdiSetFrequency:_FAR, cdiSetLinear:_FAR, cdiSetPosition:_FAR
        CGLOBAL cdiSetPanning:_FAR, cdiSetMasterVolume:_FAR, cdiMute:_FAR, cdiUnmute:_FAR
	CGLOBAL cdiMuteAll:_FAR, cdiUnmuteAll:_FAR, cdiPoll:_FAR, cdiGetDelta:_FAR
        CGLOBAL cdiDownloadSample:_FAR, cdiUnloadSample:_FAR, cdiUnloadAll:_FAR
        CGLOBAL cdiGetVolume:_FAR, cdiGetFrequency:_FAR, cdiGetPosition:_FAR
        CGLOBAL cdiGetPanning:_FAR, cdiGetInstrument:_FAR, cdiSetupChannels:_FAR
        CGLOBAL cdiGetChannelStatus:_FAR

        CDI_INITED = 1
