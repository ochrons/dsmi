Comparing files STMLOAD.C and D:\STMLOAD.C
***** STMLOAD.C


***** D:\STMLOAD.C

void far mcpConvertSample(void far *, ulong);

*****

***** STMLOAD.C
static uchar    patUsed[255];
static uchar    order4[4] = {PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT};
extern int      loadOptions;
***** D:\STMLOAD.C
static uchar    patUsed[255];
static uchar    order4[4] = {0,1,3,2};
static uchar    order8[8] = {0,1,3,2,4,5,7,6};
extern int      loadOptions;
*****

***** STMLOAD.C
            (*module->tracks)[curTrack++] = STM2AMF(buffer,1,module);
            (*module->tracks)[curTrack++] = STM2AMF(buffer,2,module);
            (*module->tracks)[curTrack++] = STM2AMF(buffer,3,module);
            }
***** D:\STMLOAD.C
            (*module->tracks)[curTrack++] = STM2AMF(buffer,1,module);
            (*module->tracks)[curTrack++] = STM2AMF(buffer,3,module);
            (*module->tracks)[curTrack++] = STM2AMF(buffer,2,module);
            }
*****

***** STMLOAD.C
        module->channelCount = 4;
        memcpy(&module->channelPanning,&order4,4);
        }
***** D:\STMLOAD.C
        module->channelCount = 4;
        memcpy(&module->channelOrder,&order4,4);
        }
*****


