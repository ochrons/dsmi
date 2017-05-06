uses csupport;

procedure ex1; far;
begin writeln('1') end;

procedure ex2; far;
begin writeln('2') end;

begin
  atexit(@ex1);
  atexit(@ex2);
end.
