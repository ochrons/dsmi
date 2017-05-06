Unit GetCPU;

Interface

Function GetCPUtype:Integer;
Function inV86:Boolean;

Implementation

Function GetCPUtype; External;
Function inV86:Boolean; External;

{$L GETCPU.OBJ}
{$L CHECKV86.OBJ}

end.
