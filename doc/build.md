# How To Compile Pikchr

## Overview

  *  Primary source file: "`pikchr.y`"
  *  Process "`pikchr.y`" using Lemon (sources provided in tree)
     to create "`pikchr.c`"
  *  Compile "`pikchr.c`" into a object file, or add the
     "`-DPIKCHR_SHELL`" command-line option to generate a stand-alone
     executable.

~~~ pikchr center
            filewid *= 1.2
  Src:      file "pikchr.y"; move
  LemonSrc: file "lemon.c"; move
  Lempar:   file "lempar.y"; move
            arrow down from LemonSrc.s
  CC1:      oval "C-Compiler" ht 50%
            arrow " generates" ljust above
  Lemon:    oval "lemon" ht 50%
            arrow from Src chop down until even with CC1 \
              then to Lemon.nw
            "Pikchr source " rjust "code input " rjust \
              at 2nd vertex of previous
            arrow from Lempar chop down until even with CC1 \
              then to Lemon.ne
            " parser template" ljust " resource file" ljust \
              at 2nd vertex of previous
  PikSrc:   file "pikchr.c" with .n at lineht below Lemon.s
            arrow from Lemon to PikSrc chop
            arrow down from PikSrc.s
  CC2:      oval "C-Compiler" ht 50%
            arrow
  Out:      file "pikchr.o" "or" "pikchr.exe" wid 110%
~~~

## Details:

The source code for Pikchr is in the file named "`pikchr.y`".  As
the ".y" suffix implies, this file is grammar specification intended
as input to the yacc-like LALR(1) parser generated program
"[Lemon][lemon]".  Even though "pikchr.y" is technically a Lemon
grammar file, it consists of mostly C-code and only 6% grammar.

Running the command:

~~~~
   lemon pikchr.y
~~~~

Generates "`pikchr.c`" as an output file.  (Lemon generates a couple
of other output files that can be ignored for this project.)  The
"pikchr.c" file is pure C code ready to be compiled into the final
application.  It can be compiled by itself with the
"-DPIKCHR_SHELL" command-line option to generate a standalone program
that reads Pikchr scripts and emits HTML with embedded SVG.  Or
it can be integrated into a larger application which invokes the
"`pikchr()`" C-API to do conversions from Pikchr to SVG.

The Lemon tool is not widely depolyed, so the sources for 
Lemon are included in the Pikchr source tree for convenience.
Compile the "`lemon.c`" source program into an executable using
any ordinary C-compiler.

When the lemon executable runs, it looks for the "`lempar.c`" template
in the working directory.  The "`lempar.c`" template is also included
in the Pikchr source repository for convenience.

[lemon]: https://www.sqlite.org/lemon.html

## Preprocessed Sources Available For Download.

If you don't want to go to the trouble of compiling Lemon and then
running the "`pikchr.y`" source file through Lemon to generate
the "`pikchr.c`" C-code, you can download a pre-built copy
of "`pikchr.c`" directly from the
[Fossil source repository][piksrc].

[piksrc]: https://fossil-scm.org/home/file/src/pikchr.c
