# Makefile for CMunge
#

COMPONENT  = CMunge
TYPE       = aif
INCLUDES   = 
OBJS       = \
        o.apcscli       \
        o.assemble      \
        o.comments      \
        o.datestamp     \
        o.error         \
        o.filename      \
        o.format        \
        o.main          \
        o.mem           \
        o.options       \
        o.readfile      \
        o.str           \
        o.system        \
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
