.EXTENSIONS::
.EXTENSIONS: .exe .obj .asm .c .cpp :

#		*Translator Definitions*
CC = bcc +DSMI.CFG
TASM = TASM
TLIB = tlib
TLINK = tlink
LIBPATH = F:\BC\LIB
INCLUDEPATH = F:\BC\INCLUDE;F:\bc\include\sys
PACKER = lha
PACK_UPDATE = u
PACK_STORE = -z
PACK_FRESHEN = u
PACK_ADD = a
PACKEXT = LZH
P2EXE = s
#		*Implicit Rules*
.c.obj:
  $(CC) -c {$< }

.cpp.obj:
  $(CC) -c {$< }

.asm.obj:
  $(TASM) /m5 /mx /zd /d__C16__ {$<;}

#		*List Macros*


LIB_dependencies =  \
 amplayer.obj \
 mcplayer.obj \
 detpas.obj \
 detaria.obj \
 detsbhw.obj \
 detsb16h.obj \
 convsamp.obj \
 mixer.obj \
 sdi_dac.obj \
 sdi_pas.obj \
 sdi_sb.obj \
 sdi_sb16.obj \
 sdi_aria.obj \
 sdi_wss.obj \
 dmaprocs.obj \
 timeserv.obj \
 emshard.obj \
 vds.obj \
 gus.obj \
 cdi.obj \
 mcpreala.obj \
 detgus.obj \
 detsb.obj \
 amfload.obj \
 freem.obj \
 initdsmi.obj \
 loadm.obj \
 modload.obj \
 stmload.obj \
 669load.obj \
 s3mload.obj \
 mtmload.obj \
 farload.obj \
 emsheap.obj \
 mcpems.obj \
 gusheap.obj \
 dsmimem.obj

DSMI_HEADERS = \
 amp.h \
 cdi.h \
 det*.h \
 dsmi*.h \
 mcp.h \
 mixer.h \
 sdi_*.h \
 timeserv.h \
 emhm.h \
 vds.h \
 gus*.h \
 *.inc

#		*Explicit Rules*
dsmi.lib: dsmi.cfg $(LIB_dependencies)
  - del dsmi.lib
  $(TLIB) $< /C /E @&&|
+amplayer.obj &
+detpas.obj &
+detaria.obj &
+detgus.obj &
+detsb.obj &
+detsbhw.obj &
+detsb16h.obj &
+mcplayer.obj &
+convsamp.obj &
+mcpreala.obj &
+mixer.obj &
+sdi_dac.obj &
+sdi_pas.obj &
+sdi_sb.obj &
+sdi_sb16.obj &
+sdi_aria.obj &
+sdi_wss.obj &
+dmaprocs.obj &
+timeserv.obj &
+amfload.obj &
+freem.obj &
+initdsmi.obj &
+loadm.obj &
+modload.obj &
+stmload.obj &
+669load.obj &
+s3mload.obj &
+mtmload.obj &
+farload.obj &
+vds.obj &
+gus.obj &
+gusheap.obj &
+cdi.obj &
+dsmimem.obj
|

dsmiems.lib : dsmi.cfg $(LIB_dependencies)
  - del dsmiems.lib
  $(CC) -c -D_USE_EMS amfload.c 669load.c modload.c farload.c mtmload.c stmload.c s3mload.c freem.c
  $(TLIB) $< /C /E @&&|
+mcpems.obj &
+amfload.obj &
+freem.obj &
+modload.obj &
+stmload.obj &
+669load.obj &
+s3mload.obj &
+mtmload.obj &
+farload.obj &
+emsheap.obj &
+emshard.obj
|


#		*Individual File Dependencies*

#		*Compiler Configuration File*
dsmi.cfg:
  copy &&|
-ml
-3
-O
-O2bgiltve
-f-
-k-
-d
-h
-y
-v-
-H=DSMI.SYM
-wpro
-weas
-wpre
-I$(INCLUDEPATH)
-L$(LIBPATH)
-D__C16__
| dsmi.cfg

obj.$(PACKEXT): $(LIB_dependencies)
  - del obj.$(PACKEXT)
  $(PACKER) $(PACK_ADD) obj.$(PACKEXT) @&&|
amplayer.obj
detpas.obj
detaria.obj
detgus.obj
detsb.obj
detsb16h.obj
detsbhw.obj
mcplayer.obj
convsamp.obj
mcpreala.obj
mixer.obj
sdi_dac.obj
sdi_pas.obj
sdi_sb.obj
sdi_sb16.obj
sdi_aria.obj
sdi_wss.obj
timeserv.obj
freem.obj
loadm.obj
amfload.obj
modload.obj
stmload.obj
669load.obj
s3mload.obj
mtmload.obj
farload.obj
initdsmi.obj
vds.obj
gus.obj
gusheap.obj
cdi.obj
dmaprocs.obj
dsmimem.obj
|

objems.$(PACKEXT): $(LIB_dependencies)
  - del objems.$(PACKEXT)
  $(PACKER) $(PACK_ADD) objems @&&|
freem.obj
amfload.obj
modload.obj
stmload.obj
669load.obj
s3mload.obj
mtmload.obj
farload.obj
emsheap.obj
emshard.obj
mcpems.obj
|

source.$(PACKEXT):
  - del source.$(PACKEXT)
  $(PACKER) $(PACK_ADD) source @&&|
amfload.c
initdsmi.c
loadm.c
freem.c
modload.c
stmload.c
669load.c
s3mload.c
mtmload.c
farload.c
mcpreala.asm
convsamp.asm
emsheap.c
emshard.asm
mcpems.c
sdi*.asm
amplayer.asm
mcplayer.asm
det*.asm
detgus.c
detsb.c
timeserv.asm
*.inc
mixer.asm
vds.asm
gus.asm
gusheap.c
cdi.asm
dmaprocs.asm
dsmimem.c
d_watcom.asm
makefile
|

include.$(PACKEXT): $(DSMI_HEADERS)
  $(PACKER) $(PACK_FRESHEN) include $(DSMI_HEADERS)
lib.$(PACKEXT): dsmi.lib dsmiems.lib
  $(PACKER) $(PACK_FRESHEN) lib dsmi.lib dsmiems.lib
examples.$(PACKEXT): example?.c dmp.c *.prj
  $(PACKER) $(PACK_FRESHEN) examples @examples.lst
toexe: dsmi.lib obj.$(PACKEXT) dsmiems.lib objems.$(PACKEXT) lib.$(PACKEXT) include.$(PACKEXT) source.$(PACKEXT) examples.$(PACKEXT)


