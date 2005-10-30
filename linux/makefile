TARGET = cmunge
LIBS = 
INCS = 
CDEFINES = 
OBJS = \
  blank.o\
  writefile.o\
  writeexport.o\
  writeheader.o\
  throwback.o\
  gfile.o\
  system.o\
  str.o\
  readfile.o\
  options.o\
  mem.o\
  main.o\
  format.o\
  filename.o\
  error.o\
  datestamp.o\
  comments.o\
  assemble.o\
  apcscli.o

.SUFFIXES: .s .c .c++ .o

.PHONY: all checklinks clean

# Every time we're run we check that the links are sensible. This keeps
# us consistent
all: $(TARGET) checklinks

.s.o:
	objasm -predefine "No26bitCode SETL {FALSE}" -predefine "No32bitCode SETL {TRUE}" -o ../o/$* $?
	cp ../o/$* $*.o
.c.o:
	cc -funsigned-char $(CDEFINES) $(INCS) -I. -I.. -c -o $@ $<
.c++.o:
	cc -funsigned-char $(CDEFINES) $(INCS) -I. -I.. -c -o $@ $<

$(TARGET): $(OBJS) $(LIBS)
	cc -o $(TARGET) $(OBJS) $(LIBS)

clean:
	-rm *.o
	-rm $(TARGET)

# And an explicit check for this
checklinks:
	@mklinks

