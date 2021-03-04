# How To Compile Pikchr

## Overview

  *  Primary source file: "`pikchr.y`"
  *  Process "`pikchr.y`" using Lemon (sources provided in tree)
     to create "`pikchr.c`"
  *  Compile "`pikchr.c`" into an object file, or add the
     "`-DPIKCHR_SHELL`" command-line option to generate a stand-alone
     executable.
  *  A pre-processed "[`pikchr.c`][src]" source file is stored in the
     source tree for the convenience of integrators who do not want to
     figure out how to build and run Lemon.

[src]: /file/pikchr.c

~~~ pikchr
            filewid *= 1.2
  Src:      file "pikchr.y"; move
  LemonSrc: file "lemon.c"; move
  Lempar:   file "lempar.y"; move
            arrow down from LemonSrc.s
  CC1:      oval "C-Compiler" ht 50%
            arrow " generates" ljust above
  Lemon:    oval "lemon" ht 50%
            arrow from Src chop down until even with CC1 \
              then to Lemon.nw rad 10px
            "Pikchr source " rjust "code input " rjust \
              at 2nd vertex of previous
            arrow from Lempar chop down until even with CC1 \
              then to Lemon.ne rad 10px
            " parser template" ljust " resource file" ljust \
              at 2nd vertex of previous
  PikSrc:   file "pikchr.c" with .n at lineht below Lemon.s
            arrow from Lemon to PikSrc chop
            arrow down from PikSrc.s
  CC2:      oval "C-Compiler" ht 50%
            arrow
  Out:      file "pikchr.o" "or" "pikchr.exe" wid 110%
            spline <- from 1mm west of Src.w go 60% heading 250 \
               then go 40% heading 45 then go 60% heading 250 \
               thin color gray
            box invis "Canonical" ljust small "Source code" ljust small fit \
               with .e at end of last spline width 90%
            spline <- from 1mm west of PikSrc.w go 60% heading 250 \
               then go 40% heading 45 then go 60% heading 250 \
               thin color gray
            box invis "Preprocessed" ljust small \
              "C-code" ljust small "also in-tree" ljust small fit \
               with .e at end of last spline width 90%
~~~

## Details:

The source code for Pikchr is in the file named "`pikchr.y`".  As
the ".y" suffix implies, this file is a grammar specification intended
as input to the yacc-like LALR(1) parser generator program
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

As the Lemon tool is not widely deployed, the source code for 
Lemon is included in the Pikchr source tree for convenience.
Compile the "`lemon.c`" source program into an executable using
any ordinary C-compiler.

When the lemon executable runs, it looks for the "`lempar.c`" template
in the working directory.  The "`lempar.c`" template is also included
in the Pikchr source repository for convenience.

[lemon]: https://www.sqlite.org/lemon.html

## Preprocessed Sources Available For Download.

As a convenience to integrators, the pre-processed "`pikchr.c`" C-code
file is normally checked into the Pikchr source tree.  Hence, to build
Pikchr into another system, just grab a copy of that one file and add
it to the project.
