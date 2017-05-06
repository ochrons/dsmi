{ -------------------------------------------------------------------------- }
{                                                                            }
{                                MCPREALA.PAS                                }
{                                ------------                                }
{                                                                            }
{                         (C) 1993 Jussi Lahdenniemi                         }
{                                                                            }
{                                                                            }
{ Pascal unit header for the null MCP real address functions                 }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit mcpreala;

interface

function mcpSampleRealAddress(id:longint;pos:longint):pointer;
procedure mcpEnableVirtualSamples;
procedure mcpDisableVirtualSamples;

implementation

function mcpSampleRealAddress(id:longint;pos:longint):pointer; external;
procedure mcpEnableVirtualSamples; external;
procedure mcpDisableVirtualSamples; external;

{$L mcpreala.obj}

end.
