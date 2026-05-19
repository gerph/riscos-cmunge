# CMunge

CMunge is a tool for RISC OS developers that generates the glue code needed to write relocatable RISC OS modules in C or C++. It is a free, enhanced alternative to Acorn/Castle CMHG and is designed to process the same style of module description files.

Rather than emitting the final object file directly, CMunge generates assembly source for the veneer layer between the RISC OS kernel and C or C++ code, and can then drive an assembler to produce the module object. This keeps the module-facing boilerplate out of the application code while handling module headers, SWI dispatch, command parsing, service handling, and related low-level details.

## Features

- Compatible with CMHG-style input files.
- Generates veneers for module initialisation, finalisation, SWIs, commands, services, vectors, and related entry points.
- Supports 26-bit ARM, 32-bit ARM, and 64-bit AArch64 output.
- Supports Norcroft, GCC, and legacy LCC toolchain modes.
- Can preprocess description files with `-p` or `-px`.
- Adds CMunge-specific features beyond classic CMHG, including:
  - error base handling and generated error identifiers
  - SWI-specific handlers in decoding tables
  - vector trap handlers
  - enhanced generic veneer support
  - non-reentrant module support
  - improved C++ module support
  - 64-bit code generation

## What CMunge Does

CMunge reads a CMHG/CMunge description file and generates the veneer code needed to bridge RISC OS module interfaces to C or C++ functions. In practice that means it can generate support for:

- module title and help strings
- module initialisation and finalisation handlers
- service call handlers
- SWI dispatch tables and SWI decoding
- `*Command` tables and handlers
- generic veneers, vector handlers, and event handlers

The companion PRM-in-XML documentation in [`prminxml/cmunge.xml`](prminxml/cmunge.xml) and [`prminxml/cmhg-format.xml`](prminxml/cmhg-format.xml) documents both the tool and the input format in more detail.

## Command Line

The basic form is:

```text
CMunge [options] <infile>
```

Common options:

- `-o <file>`: output object file
- `-s <file>`: output assembly file
- `-d <file>`: generated C header file
- `-xhdr <file>`: exported assembler SWI header
- `-xh <file>`: exported C SWI header
- `-p`: preprocess input
- `-px`: extended preprocess mode
- `-depend <file>`: write dependency information for AMU
- `-throwback`: enable throwback error reporting
- `-26bit`: generate 26-bit code
- `-32bit`: generate 32-bit compatible code
- `-64bit`: generate 64-bit AArch64 code
- `-apcs <variant>`: select APCS variant
- `-tnorcroft`, `-tgcc`, `-tlcc`: select toolchain
- `-blank`: generate a template input file
- `-cmhg`: warn about CMHG-incompatible constructs
- `-zoslib`, `-zoslibpath`: select OSLib header style
- `-zerrors`: generate error and veneer definitions only

Example:

```text
CMunge -32bit -d h.modhdr -o o.modhdr cmhg.ModDesc
```

## CMHG / CMunge Input Format

CMunge uses the CMHG file format, a small domain-specific language for describing a RISC OS relocatable module.

At a high level:

- the file is a sequence of directives
- directives are written as `keyword: value`
- keywords are case-insensitive
- comments begin with `;`
- a trailing comma continues a logical line onto the next physical line
- strings are double-quoted
- numbers may be decimal, `&`-prefixed hexadecimal, or `0x`-prefixed hexadecimal

Typical directives include:

- `title-string`
- `help-string`
- `initialisation-code`
- `finalisation-code`
- `service-call-handler`
- `swi-chunk-base-number`
- `swi-handler-code`
- `swi-decoding-table`
- `command-keyword-table`
- `generic-veneers`
- `vector-handlers`
- `event-handler`

CMunge also extends the original format with directives and behaviours for modern development, including 32-bit and 64-bit support, error identifier generation, early initialisation, and more flexible veneer handling.

## Building

This repository is set up for the RISC OS build environment and builds `CMunge` as an `aif` tool.

Repository build entry points:

- `Makefile`
- `.robuild.yaml`
- `crosscompile/`

Typical build command in the RISC OS build environment:

```text
amu -f Makefile install INSTDIR=Install
```

The CI build configuration in [`.robuild.yaml`](.robuild.yaml) builds the tool and then runs `aif32.CMunge`.

## Repository Layout

- [`c/`](c/) - C source files
- [`h/`](h/) - headers
- [`prminxml/`](prminxml/) - PRM-in-XML documentation sources
- [`testdata/`](testdata/) - test inputs and expected outputs
- [`crosscompile/`](crosscompile/) - cross-compilation support files

## Status

The source tree includes substantial work beyond older CMHG-compatible behaviour, notably 32-bit support, 64-bit AArch64 support, updated build integration, and regression test data for multiple output variants.

## Documentation

Full documentation is in the repository's PRM-in-XML sources:

- [`prminxml/cmunge.xml`](prminxml/cmunge.xml)
- [`prminxml/cmhg-format.xml`](prminxml/cmhg-format.xml)

Which are built into documentation within the release archives.
