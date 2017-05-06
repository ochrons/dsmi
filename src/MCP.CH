Comparing files MCP.H and D:\MCP.H
***** MCP.H

#define CH_PLAYING      1
#define CH_LOOPING      2
#define CH_PAUSED       4
#define CH_VALID        8

#define PAN_LEFT -63
#define PAN_RIGHT 63
#define PAN_MIDDLE 0

#ifdef __cplusplus
***** D:\MCP.H

#ifdef __cplusplus
*****

***** MCP.H
void  far mcpCloseSpeaker( void );
short far mcpOpenChannels( short channels, short volumemode, ushort far *volTable );
short far mcpStartVoice( void );
***** D:\MCP.H
void  far mcpCloseSpeaker( void );
short far mcpOpenChannels( short channels, short volumemode, short far *volTable );
short far mcpStartVoice( void );
*****

***** MCP.H
short far mcpSetPosition( short channel, ulong position );
short far mcpSetPanning( short channel, short panning );
short far mcpSetSamplingRate( ushort sampling_rate );
***** D:\MCP.H
short far mcpSetPosition( short channel, ulong position );
short far mcpSetSamplingRate( ushort sampling_rate );
*****


