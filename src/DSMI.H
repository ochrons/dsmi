// ************************************************************************
// *
// *    File        : DSMI.H
// *
// *    Description : Main header file for DSMI
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#ifndef __DEF_DSMI
#define __DEF_DSMI

#include "mcp.h"
#include "gus.h"
#include "gushm.h"
#include "cdi.h"
#include "sdi_dac.h"
#include "sdi_sb.h"
#include "sdi_sb16.h"
#include "sdi_pas.h"
#include "sdi_wss.h"
#include "detpas.h"
#include "detsb.h"
#include "detgus.h"
#include "amp.h"
#include "timeserv.h"

// Following stuff is not in DSMI/32
#ifndef __C32__
#include "sdi_aria.h"
#include "detaria.h"
#include "mixer.h"
#include "vds.h"
#endif

#define NO_SOUNDCARD -1
#define INVALID_SDI -2
#define NO_MEMORY -3
#define MCP_INITERROR -4
#define AMP_INITERROR -5

#ifdef __cplusplus
extern "C" {
#endif

int cdecl initDSMI(long rate, long buffer, long options, SOUNDCARD *scard);

#ifdef __cplusplus
}
#endif
#endif
