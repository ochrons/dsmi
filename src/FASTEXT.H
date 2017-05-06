// ************************************************************************
// *
// *    File        : FASTEXT.H
// *
// *    Description : Fast directvideo routines for text output.
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

typedef unsigned short ushort;

int initFastext(void);
void updateBuffer(ushort start, ushort count);
void writeBuf(const void *buf, ushort x, ushort y, ushort count);
void writeStr(const char *str, ushort x, ushort y, ushort attr, ushort count);
void writeCStr(const char *str, ushort x, ushort y, ushort attr1, ushort attr2, ushort count);
void moveBuf(void *buf, ushort indent, const void *src, ushort count);
void moveChar(void *buf, ushort indent, char c, ushort attr, ushort count);
void moveStr(void *buf, ushort indent, const char *str, ushort attr);
void moveCStr(void *buf, ushort indent, const char *str, ushort attr1, ushort attr2);
void putChar(void *buf, ushort indent, char c);
void putAttr(void *buf, ushort indent, ushort attr);
void cursorxy(int x, int y);
