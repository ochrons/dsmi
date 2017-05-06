;$Author:   DCODY  $
;$Date:   25 Jun 1992 23:28:14  $
;$Header:   W:/sccs/inc/state.inv   1.1   25 Jun 1992 23:28:14   DCODY  $
;$Log:   W:/sccs/inc/state.inv  $
;
;   Rev 1.1   25 Jun 1992 23:28:14   DCODY
;PAS2 updated state table
;
;   Rev 1.0   15 Jun 1992 09:58:48   BCRANE
;Initial revision.
;$Logfile:   W:/sccs/inc/state.inv  $
;$Modtimes$
;$Revision:   1.1  $
;$Workfile:   state.inc  $ 


;   /*\
;---|*|----====< Pro Audio Spectrum Hardware State Table >====----
;---|*|
;---|*| Media Vision, Inc. (c) Copyright 1991. All Rights Reserved
;---|*|
;   \*/

MVState struc
  _sysspkrtmr    db     0       ;    42 System Speaker Timer Address
  _systmrctlr    db     0       ;    43 System Timer Control
  _sysspkrreg    db     0       ;    61 System Speaker Register
  _joystick      db     0       ;   201 Joystick Register
  _lfmaddr       db     0       ;   388 Left  FM Synth Address
  _lfmdata       db     0       ;   389 Left  FM Synth Data
  _rfmaddr       db     0       ;   38A Right FM Synth Address
  _rfmdata       db     0       ;   38B Right FM Synth Data
  _dfmaddr       db     0       ;   788 Dual  FM Synthesizer Address Register
  _dfmdata       db     0       ;   789 Dual  FM Synthesizer Data Register
                 db     0       ;       reserved for future use
  _paudiomixr    db     0       ;   78B Paralllel Audio Mixer Control
  _audiomixr     db     0       ;   B88 Audio Mixer Control
  _intrctlrst    db     0       ;   B89 Interrupt Status
  _audiofilt     db     0       ;   B8A Audio Filter Control
  _intrctlr      db     0       ;   B8B Interrupt Control
  _pcmdata       db     0       ;   F88 PCM Data I/O Register
  _RESRVD2       db     0       ;       reserved
  _crosschannel  db     0       ;   F8A Cross Channel
  _RESRVD3       db     0       ;       reserved
  _samplerate    dw     0       ;  1388 Sample Rate Timer
  _samplecnt     dw     0       ;  1389 Sample Count Register
  _spkrtmr       dw     0       ;  138A Shadow Speaker Timer Count
  _tmrctlr       db     0       ;  138B Shadow Speaker Timer Control
  _mdirqvect     db     0       ;  1788 MIDI IRQ Vector Register
  _mdsysctlr     db     0       ;  1789 MIDI System Control Register
  _mdsysstat     db     0       ;  178A MIDI IRQ Status Register
  _mdirqclr      db     0       ;  178B MIDI IRQ Clear Register
  _mdgroup1      db     0       ;  1B88 MIDI Group #1 Register
  _mdgroup2      db     0       ;  1B89 MIDI Group #2 Register
  _mdgroup3      db     0       ;  1B8A MIDI Group #3 Register
  _mdgroup4      db     0       ;  1B8B MIDI Group #4 Register
MVState ends


;   /*\
;---|*| end of STATE.H
;   \*/

