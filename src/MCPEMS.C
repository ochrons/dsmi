// ************************************************************************
// *
// *    File        : MCPEMS.C
// *
// *    Description : MCP EMS handler
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#include "dsmidef.h"
#include "emhm.h"

void far *mcpSampleRealAddress(ulong ID, ulong pos)
{
    return emsLock(ID,0,65535);
}

void mcpEnableVirtualSamples(void)
{
    emsSaveState();
}

void mcpDisableVirtualSamples(void)
{
    emsRestoreState();
}
