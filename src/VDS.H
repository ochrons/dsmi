// ************************************************************************
// *
// *    File        : VDS.H
// *
// *    Description : Header for Virtual DMA Services
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#ifndef __VDS_H
#define __VDS_H

typedef struct {
    ulong       size;
    ulong       offset;
    ushort      segment;
    ushort      ID;
    ulong       address;
} DDS;

#ifdef __cplusplus
extern "C" {
#endif

int cdecl vdsInit(void);
int cdecl vdsEnableDMATranslation(short DMAchannel);
int cdecl vdsDisableDMATranslation(short DMAchannel);
int cdecl vdsLockDMA(DDS *dds);
int cdecl vdsUnlockDMA(DDS *dds);

#ifdef __cplusplus
}
#endif

#endif
