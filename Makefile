# Makefile for CMunge
#

COMPONENT  = CMunge
TYPE       = aif
INCLUDES   = 
OBJS       = \
        o.assemble      \
        o.datestamp     \
        o.error         \
        o.main          \
        o.mem           \
        o.options       \
        o.readfile      \
        o.str           \
        o.gfile         \
        o.throwback     \
        o.writeheader   \
        o.writeexport   \
        o.writefile     \
        o.blank
LIBS       = ${CLIB}

include LibraryCommand


#---------------------------------------------------------------------------
# Dynamic dependencies:
