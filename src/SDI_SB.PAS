{  Original :

// ************************************************************************
// *
// *	File        : SDI_SB.H
// *
// *	Description : Header for SB (Pro) specific routines in MCP
// *
// *	Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

   Conversion :

// ************************************************************************
// *
// *	File        : SDI_SB.H
// *
// *	Description : Header for SB (Pro) specific routines in MCP
// *
// *	Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

}

Unit SDI__SB;

Interface
Uses MCP;

Procedure SDI_SB;
Procedure SDI_SBPro;

Implementation

{$L SDI_SB.OBJ}

Procedure SDI_SB; External;
Procedure SDI_SBPro; External;

End.
