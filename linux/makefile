LIBS = 
INCS = 
CDEFINES = 
OBJS = \
  apcscli.o\
  assemble.o\
  blank.o\
  comments.o\
  datestamp.o\
  error.o\
  filename.o\
  format.o\
  gfile.o\
  main.o\
  mem.o\
  options.o\
  readfile.o\
  str.o\
  system.o\
  throwback.o\
  writeexport.o\
  writefile.o\
  writeheader.o

.SUFFIXES: .s .c .c++ .o

.PHONY: checklinks clean

.s.o:
	objasm -predefine "No26bitCode SETL {FALSE}" -predefine "No32bitCode SETL {TRUE}" -o ../o/$* $?
	cp ../o/$* $*.o
.c.o:
	cc -funsigned-char $(CDEFINES) $(INCS) -I. -I.. -c -o $@ $<
.c++.o:
	cc -funsigned-char $(CDEFINES) $(INCS) -I. -I.. -c -o $@ $<

# Every time we're run we check that the links are sensible. This keeps
# us consistent
CMunge: $(OBJS) $(LIBS) checklinks
	cc -o CMunge $(OBJS) $(LIBS)

clean:
	-rm *.o
	-rm CMunge

# And an explicit check for this
checklinks:
	

