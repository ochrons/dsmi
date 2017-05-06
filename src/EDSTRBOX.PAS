(****************************************************************************

                                 EDSTRBOX.PAS
                                 ------------

Edit strings -box view

****************************************************************************)

unit edStrBox;

interface
uses views,dialogs,objects,drivers;

type PEdBoxInpLine  = ^TEdBoxInpLine;
     TEdBoxInpLine  = Object(TInputLine)
       procedure      handleEvent(var event:TEvent); virtual;
     end;

     PEdStrBox      = ^TEdStrBox;
     TEdStrBox      = Object(TListBox)
       inpLines     : array[0..99] of PEdBoxInpLine;
       constructor    init(var bounds:TRect;aScrollBar:PScrollBar);
       procedure      draw; virtual;
       procedure      handleEvent(var event:TEvent); virtual;
     end;

implementation

Procedure TEdBoxInpLine.handleEvent;
begin
  inherited handleEvent(event);
end;

Constructor TEdStrBox.init;
var w:word;
    r:TRect;
begin
  inherited init(bounds,1,aScrollBar);
  for w:=0 to size.y-1 do begin
    r.assign(0,w,size.x,w+1);
    inpLines[w]:=new(PEdBoxInpLine,init(r,size.x-2));
    owner^.insert(inpLines[w]);
  end;
end;

Procedure TEdStrBox.draw;
begin
  TView.draw;
end;

Procedure TEdStrBox.handleEvent;
begin
  inherited handleEvent(event);
end;

end.
