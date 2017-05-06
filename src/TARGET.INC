
;   /*\
;---|*|----====< TARGET.INC >====----
;---|*|
;---|*| This file defines which product is being compiled. This is used
;---|*| for the PAS software libraries, etc.
;---|*|
;---|*| Copyright (c) 1992, Media Vision, Inc.  All Rights Reserved.
;---|*|
;---|*| To use this code, you must define one of the following variable names.
;---|*|
;---|*|    BUILD_NONE - General assembly of header. No target product defined
;---|*|    BUILD_PAS1 - Original Pro Audio Spectrum.
;---|*|    BUILD_PAS2 - Pro Audio Spectrum Plus.
;---|*|    BUILD_PAS3 - Pro Audio Spectrum 16.
;---|*|    BUILD_CDPC - CDPC.
;---|*|
;   \*/

;;
;; Each product will some/all of of these features
;;

bMVA508         =       0000000000000001b       ; MVA508(1) or National(0)
bMVPS2          =       0000000000000010b       ; PS2 bus stuff
bMVSLAVE        =       0000000000000100b       ; CDPC Slave device is present
bMVSCSI         =       0000000000001000b       ; SCSI interface
bMVENHSCSI      =       0000000000010000b       ; Enhanced SCSI interface
bMVSONY         =       0000000000100000b       ; Sony 535 interface
bMVDAC16        =       0000000001000000b       ; 16 bit DAC
bMVSBEMUL       =       0000000010000000b       ; SB h/w emulation
bMVMPUEMUL      =       0000000100000000b       ; MPU h/w emulation
bMVOPL3         =       0000001000000000b       ; OPL3(1) or 3812(0)
bMV101          =       0000010000000000b       ; MV101 ASIC
bMV101_REV      =       0111100000000000b       ; MV101 Revision
bMV101_MORE     =       1000000000000000b       ; more bits in BX

;;
;; Define the ASIC versions
;;

ASIC_VERSION_B  =       0000000000000010b       ; revision B
ASIC_VERSION_C  =       0000000000000011b       ; revision C
ASIC_VERSION_D  =       0000000000000100b       ; revision D
ASIC_VERSION_E  =       0000000000000101b       ; revision E
ASIC_VERSION_F  =       0000000000000110b       ; revision F

;;
;; First Pro Audio Spectrum feature list
;;
PRODUCT_PROAUDIO        =       bMVSCSI

;;
;; Pro Audio Plus feature list
;;
PRODUCT_PROPLUS         =       bMV101+      \
                                bMVSCSI+     \
                                bMVENHSCSI+  \
                                bMVSBEMUL+   \
                                bMVOPL3
;;
;; Pro Audio Spectrum 16 feature list
;;
PRODUCT_PRO16           =       bMV101+      \
                                bMVA508+     \
                                bMVSCSI+     \
                                bMVENHSCSI+  \
                                bMVSBEMUL+   \
                                bMVDAC16+    \
                                bMVOPL3
;;
;; CDPC feature list
;;
PRODUCT_CDPC            =       bMV101+      \
                                bMVSLAVE+    \
                                bMVSONY+     \
                                bMVSBEMUL+   \
                                bMVDAC16+    \
                                bMVOPL3


;;
;; Set each one to zero - to be init later if selected
;;

PROAS100        =       0
PROAS200        =       0
PROAS300        =       0
CDPC            =       0

PRODUCTDEFINED  =       0               ;; to be set if a product is selected

;;
;;----====<  1st retail version of the Pro Audio Spectrum. >====----
;;

ifdef BUILD_PAS1
PROAS100        =       1               ;; 1st board - Pro Audio Spectrum
PRODUCTDEFINED  =       PRODUCT_PROAUDIO
endif

;;
;;----====< 8 bit Integrated PAS with rev 2 of the MV101 >====----
;;

ifdef BUILD_PAS2
PROAS200        =       1               ;; 2nd board - Pro Audio Spectrum
PRODUCTDEFINED  =       PRODUCT_PROPLUS
endif

;;
;;----====< 16 bit Integrated PAS with rev 2 of the MV101 >====----
;;

ifdef BUILD_PAS3
PROAS300        =       1               ;; 3rd board - Pro Audio Spectrum
PRODUCTDEFINED  =       PRODUCT_PRO16
endif

;;
;;----====< 1st CDPC box >====----
;;

ifdef BUILD_CDPC
CDPC            =       1               ;; CDPC stand alone box
PRODUCTDEFINED  =       PRODUCT_CDPC
endif

;;
;;----====< Generate an error if no product is defined >====----
;;

ife PRODUCTDEFINED
endif

;;
;;------------------====< Hardware Dependencies >====-------------------
;;

if PROAS100                             ;; Media Vision Pro Audio Spectrum Orig
HWREVISION      equ     00000000B       ;; the H/W revision #
endif
if PROAS200                             ;; Media Vision Pro Audio Spectrum Plus
HWREVISION      equ     00000001B       ;; the H/W revision #
endif
if PROAS300                             ;; Media Vision Pro Audio Spectrum 16
HWREVISION      equ     00000001B       ;; the H/W revision #
endif
if CDPC                                 ;; Media Vision CDPC
HWREVISION      equ     00000111B       ;; the H/W revision #
endif


if (PRODUCTDEFINED AND bMVSBEMUL)
  if (PRODUCTDEFINED AND bMVA508)
    L_SB        equ     L_FREE
    R_SB        equ     R_FREE
  else
    L_SB        equ     L_SPEAKER
    R_SB        equ     R_SPEAKER
  endif
endif


if (PRODUCTDEFINED AND bMVA508)
VOLUMEMAX       equ     MVVOLUMEMAX
else
VOLUMEMAX       equ     NSVOLUMEMAX
endif


