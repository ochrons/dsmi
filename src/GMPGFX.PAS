Unit GMPgfx;

Interface

Procedure FontData;
Procedure Piccy;
Procedure HelpScreen;
Procedure InfoScreen;

Implementation

Procedure FontData; External;
{$L GMPFONT.OBJ}
Procedure Piccy; External;
{$L GMPPIC.OBJ}
Procedure HelpScreen; External;
{$L GMPHELP.OBJ}
Procedure InfoScreen; External;
{$L GMPINFO.OBJ}

end.
