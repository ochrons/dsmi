// ************************************************************************
// *
// *    File        : DVCALLS.H
// *
// *    Description : Header file for partial DesqView API
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#ifdef __cplusplus
extern "C" {
#endif

int getDVVersion(void);
unsigned getDVVideoBuffer(void);
void dvPause(void);
void dvBeginCritical(void);
void dvEndCritical(void);

#ifdef __cplusplus
}
#endif
