// ************************************************************************
// *
// *    File        : SDI_DAC.H
// *
// *    Description : Header for general DAC device
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#ifndef __SDI_DAC_H
#define __SDI_DAC_H

#ifndef __DSMIDEF_H
#include "dsmidef.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

void cdecl SDI_DAC(void);
void cdecl setDACTimer( ushort rate );
#ifdef __cplusplus
}
#endif

#endif
