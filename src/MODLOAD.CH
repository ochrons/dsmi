Comparing files MODLOAD.C and D:\MODLOAD.C
***** MODLOAD.C

static int      curTrack;
***** D:\MODLOAD.C

void far mcpConvertSample(void far *, ulong);

static int      curTrack;
*****

***** MODLOAD.C
                                   907,900,894,887,881,875,868,862 };
static uchar    order4[4] = {PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT};
static uchar    order8[8] = {PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT};
static uchar    order6[6] = {PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT};
static uchar    insc;
***** D:\MODLOAD.C
                                   907,900,894,887,881,875,868,862 };
static uchar    order4[4] = {0,1,3,2};
static uchar    order8[8] = {0,1,3,2,4,5,7,6};
static uchar    order6[6] = {0,1,3,2,4,5};
static uchar    insc;
*****

***** MODLOAD.C
            {
            pat->track[i] = (void*)(orders[t]*module->channelCount+1+i);
            }
***** D:\MODLOAD.C
            {
            pat->track[module->channelOrder[i]] = (void*)(orders[t]*module->channelCount+1+i);
            }
*****

***** MODLOAD.C
        module->channelCount = 4;
        memcpy(&module->channelPanning,&order4,4);
        }
***** D:\MODLOAD.C
        module->channelCount = 4;
        memcpy(&module->channelOrder,&order4,4);
        }
*****

***** MODLOAD.C
        module->channelCount = 8;
        memcpy(&module->channelPanning,&order8,8);
        }
***** D:\MODLOAD.C
        module->channelCount = 8;
        memcpy(&module->channelOrder,&order8,8);
        }
*****

***** MODLOAD.C
        module->channelCount = 6;
        memcpy(&module->channelPanning,&order6,6);
        }
***** D:\MODLOAD.C
        module->channelCount = 6;
        memcpy(&module->channelOrder,&order6,6);
        }
*****

***** MODLOAD.C
        module->channelCount = 8;
        memcpy(&module->channelPanning,&order8,8);
        }
***** D:\MODLOAD.C
        module->channelCount = 8;
        memcpy(&module->channelOrder,&order8,8);
        }
*****

***** MODLOAD.C
        module->channelCount = 4;
        memcpy(&module->channelPanning,&order8,4);
        }
***** D:\MODLOAD.C
        module->channelCount = 4;
        memcpy(&module->channelOrder,&order8,4);
        }
*****


