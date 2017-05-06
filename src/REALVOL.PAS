function realVolume(track:integer):integer;
type ta=array[0..65519] of byte;
var t,orgvol         : integer;
    ave,vol          : longint;
    hsample,sample   : ^ta;
begin
  orgvol:=mcpGetChannelVolume(track);
  if (orgvol=0) or (mcpGetChannelStatus(track) and CH_PLAYING=0) then begin
    realVolume:=0;
    exit;
  end;
  hsample:=pointer(mcpGetChannelSample(track));
  inc(longint(hsample),mcpGetChannelPosition(track));
  sample:=hsample;
  vol:=0;
  for t:=0 to 127 do inc(vol,abs(shortint(sample^[t] xor $80)));
  vol:=vol*longint(orgvol) div longint(10000);
  if vol>64 then vol:=64;
  realVolume:=vol;
end;

