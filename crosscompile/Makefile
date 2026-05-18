COMPONENT = riscos-cmunge
CC = gcc
#LIBS = $(RO_NATIVE)/CLX/clx.a
#INCS = -I$(RO_NATIVE)/CLX/
CDEFINES =
ifneq ($(CI_BRANCH_VERSION),)
CDEFINES += -DBUILD_VERSION=\"$(CI_BRANCH_VERSION)\"
endif
PLATFORM_CFLAGS ?= -fPIC
CFLAGS = -Wall -g $(PLATFORM_CFLAGS) -funsigned-char $(INCS)
JUNITXML ?= ../artifacts/results.xml

# Any more arguments to pass to the tool (largely so we can use -tgcc)
EXTRA_ARGS ?=

FILES = \
	apcscli.c apcscli.h assemble.c assemble.h \
	blank.c blank.h comments.c comments.h \
	copyright.h datestamp.c datestamp.h error.c \
	error.h filename.c filename.h format.c \
	format.h gfile.c gfile.h main.c \
	mem.c mem.h MemCheck.h options.c \
	options.h readfile.c readfile.h str.c \
	str.h system.c system.h throwback.c \
	throwback.h VersionNum writeexport.c writeexport.h \
	writefile.c writefile.h writeheader.c writeheader.h

OBJS = \
  apcscli.o \
  assemble.o \
  blank.o \
  comments.o \
  datestamp.o \
  error.o \
  filename.o \
  format.o \
  gfile.o \
  main.o \
  mem.o \
  options.o \
  readfile.o \
  str.o \
  system.o \
  throwback.o \
  writeexport.o \
  writefile.o \
  writeheader.o

.PHONY: all links cross_export cross_install tool_dir clean

all: $(COMPONENT)
links: $(FILES)

cross_export:
	@echo No exports

cross_install: \
		tool_dir \
		test \
		$(ROTOOL_DIR)/$(COMPONENT)
	@echo Installed to $(ROTOOL_DIR)

$(ROTOOL_DIR)/%: %
	cp $? $@

tool_dir:
	mkdir -p $(ROTOOL_DIR)

test: $(COMPONENT)
	mkdir -p ../testdata/o
	mkdir -p ../testdata/h
	mkdir -p ../testdata/hdr
	mkdir -p ../testdata/s
	mkdir -p ../artifacts
	perl ../testdata/test.pl --junitxml "${JUNITXML}" --show-command --show-output "$(shell pwd)/$(COMPONENT) ${EXTRA_ARGS}" ../testdata

clean:
	-rm -f *.c *.h VersionNum *.o $(COMPONENT)

%.o: %.c
	$(CC) $(CFLAGS) $(CDEFINES) -c -o $@ $<

$(COMPONENT): $(OBJS) $(LIBS)
	$(CC) -g -o $(COMPONENT) $(OBJS) $(LIBS)

# Links
apcscli.o: apcscli.c apcscli.h
apcscli.c: ../c/apcscli
	ln -sf ../c/apcscli apcscli.c
apcscli.h: ../h/apcscli
	ln -sf ../h/apcscli apcscli.h
assemble.o: assemble.c datestamp.h error.h mem.h options.h system.h apcscli.h
assemble.c: ../c/assemble
	ln -sf ../c/assemble assemble.c
assemble.h: ../h/assemble
	ln -sf ../h/assemble assemble.h
blank.o: blank.c error.h options.h format.h readfile.h filename.h VersionNum
blank.c: ../c/blank
	ln -sf ../c/blank blank.c
blank.h: ../h/blank
	ln -sf ../h/blank blank.h
comments.o: comments.c format.h comments.h
comments.c: ../c/comments
	ln -sf ../c/comments comments.c
comments.h: ../h/comments
	ln -sf ../h/comments comments.h
copyright.h: ../h/copyright
	ln -sf ../h/copyright copyright.h
datestamp.o: datestamp.c datestamp.h error.h mem.h options.h
datestamp.c: ../c/datestamp
	ln -sf ../c/datestamp datestamp.c
datestamp.h: ../h/datestamp
	ln -sf ../h/datestamp datestamp.h
error.o: error.c options.h throwback.h
error.c: ../c/error
	ln -sf ../c/error error.c
error.h: ../h/error
	ln -sf ../h/error error.h
filename.o: filename.c filename.h
filename.c: ../c/filename
	ln -sf ../c/filename filename.c
filename.h: ../h/filename
	ln -sf ../h/filename filename.h
format.o: format.c format.h
format.c: ../c/format
	ln -sf ../c/format format.c
format.h: ../h/format
	ln -sf ../h/format format.h
gfile.o: gfile.c gfile.h str.h filename.h
gfile.c: ../c/gfile
	ln -sf ../c/gfile gfile.c
gfile.h: ../h/gfile
	ln -sf ../h/gfile gfile.h
main.o: main.c MemCheck.h gfile.h options.h readfile.h writefile.h writeheader.h writeexport.h assemble.h datestamp.h blank.h format.h copyright.h VersionNum
main.c: ../c/main
	ln -sf ../c/main main.c
mem.o: mem.c error.h
mem.c: ../c/mem
	ln -sf ../c/mem mem.c
mem.h: ../h/mem
	ln -sf ../h/mem mem.h
MemCheck.h: ../h/MemCheck
	ln -sf ../h/MemCheck MemCheck.h
options.o: options.c gfile.h error.h options.h str.h mem.h format.h apcscli.h
options.c: ../c/options
	ln -sf ../c/options options.c
options.h: ../h/options
	ln -sf ../h/options options.h
readfile.o: readfile.c gfile.h error.h mem.h options.h str.h readfile.h system.h filename.h
readfile.c: ../c/readfile
	ln -sf ../c/readfile readfile.c
readfile.h: ../h/readfile
	ln -sf ../h/readfile readfile.h
str.o: str.c error.h mem.h str.h
str.c: ../c/str
	ln -sf ../c/str str.c
str.h: ../h/str
	ln -sf ../h/str str.h
system.o: system.c error.h
system.c: ../c/system
	ln -sf ../c/system system.c
system.h: ../h/system
	ln -sf ../h/system system.h
throwback.o: throwback.c throwback.h
throwback.c: ../c/throwback
	ln -sf ../c/throwback throwback.c
throwback.h: ../h/throwback
	ln -sf ../h/throwback throwback.h
VersionNum: ../VersionNum
	ln -sf ../VersionNum VersionNum
writeexport.o: writeexport.c gfile.h error.h options.h comments.h copyright.h VersionNum
writeexport.c: ../c/writeexport
	ln -sf ../c/writeexport writeexport.c
writeexport.h: ../h/writeexport
	ln -sf ../h/writeexport writeexport.h
writefile.o: writefile.c gfile.h error.h options.h apcscli.h copyright.h VersionNum
writefile.c: ../c/writefile
	ln -sf ../c/writefile writefile.c
writefile.h: ../h/writefile
	ln -sf ../h/writefile writefile.h
writeheader.o: writeheader.c gfile.h error.h options.h format.h comments.h copyright.h VersionNum
writeheader.c: ../c/writeheader
	ln -sf ../c/writeheader writeheader.c
writeheader.h: ../h/writeheader
	ln -sf ../h/writeheader writeheader.h
