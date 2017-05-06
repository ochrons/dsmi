begin
  repeat
    writeln(memw[seg0040:$80],' ',memw[seg0040:$82],' ',memw[seg0040:mem[seg0040:$1c]-2]);
  until false;
end.

