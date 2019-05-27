# Microsoft Developer Studio Project File - Name="CMunge" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Console Application" 0x0103

CFG=CMunge - Win32 Release
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "CMunge.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "CMunge.mak" CFG="objasm - Win32 Release"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "CMunge - Win32 Release" (based on "Win32 (x86) Console Application")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=cl.exe
RSC=rc.exe
# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Win32"
# PROP Intermediate_Dir "Win32"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_CONSOLE" /D "_MBCS" /YX /FD /c
# ADD CPP /nologo /Za /W3 /O2 /I "..\..\..\..\\Sources\Lib\CLX\linux\\" /I "..\\" /D "WIN32" /D "NDEBUG" /D "_CONSOLE" /D "_MBCS"  /FD /c
# SUBTRACT CPP /YX /Yc /Yu
# ADD BASE RSC /l 0x809 /d "NDEBUG"
# ADD RSC /l 0x809 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib shell32.lib kernel32.lib user32.lib gdi32.lib comdlg32.lib shell32.lib /nologo  /subsystem:console /machine:I386
# ADD LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib shell32.lib kernel32.lib user32.lib gdi32.lib comdlg32.lib shell32.lib clx.lib /nologo /subsystem:console /pdb:none /machine:I386 /libpath:"..\..\..\..\\Sources\Lib\CLX\linux\Win32\\" /out:"..\..\..\..\\Install\BuildTools\Win32\cmunge.exe"
# Begin Target

# Name "CMunge - Win32 Release"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# Begin Source File

SOURCE=blank.c
# End Source File
# Begin Source File

SOURCE=writefile.c
# End Source File
# Begin Source File

SOURCE=writeexport.c
# End Source File
# Begin Source File

SOURCE=writeheader.c
# End Source File
# Begin Source File

SOURCE=throwback.c
# End Source File
# Begin Source File

SOURCE=gfile.c
# End Source File
# Begin Source File

SOURCE=system.c
# End Source File
# Begin Source File

SOURCE=str.c
# End Source File
# Begin Source File

SOURCE=readfile.c
# End Source File
# Begin Source File

SOURCE=options.c
# End Source File
# Begin Source File

SOURCE=mem.c
# End Source File
# Begin Source File

SOURCE=main.c
# End Source File
# Begin Source File

SOURCE=format.c
# End Source File
# Begin Source File

SOURCE=filename.c
# End Source File
# Begin Source File

SOURCE=error.c
# End Source File
# Begin Source File

SOURCE=datestamp.c
# End Source File
# Begin Source File

SOURCE=comments.c
# End Source File
# Begin Source File

SOURCE=assemble.c
# End Source File
# Begin Source File

SOURCE=apcscli.c
# End Source File
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "h;hpp;hxx;hm;inl"
# Begin Source File

SOURCE=apcscli.h
# End Source File
# Begin Source File

SOURCE=assemble.h
# End Source File
# Begin Source File

SOURCE=blank.h
# End Source File
# Begin Source File

SOURCE=comments.h
# End Source File
# Begin Source File

SOURCE=copyright.h
# End Source File
# Begin Source File

SOURCE=datestamp.h
# End Source File
# Begin Source File

SOURCE=error.h
# End Source File
# Begin Source File

SOURCE=filename.h
# End Source File
# Begin Source File

SOURCE=format.h
# End Source File
# Begin Source File

SOURCE=gfile.h
# End Source File
# Begin Source File

SOURCE=mem.h
# End Source File
# Begin Source File

SOURCE=MemCheck.h
# End Source File
# Begin Source File

SOURCE=options.h
# End Source File
# Begin Source File

SOURCE=readfile.h
# End Source File
# Begin Source File

SOURCE=str.h
# End Source File
# Begin Source File

SOURCE=system.h
# End Source File
# Begin Source File

SOURCE=throwback.h
# End Source File
# Begin Source File

SOURCE=writeexport.h
# End Source File
# Begin Source File

SOURCE=writefile.h
# End Source File
# Begin Source File

SOURCE=writeheader.h
# End Source File
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
# End Group
# End Target
# End Project
