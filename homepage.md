Pikchr (pronounced like "picture") is a [PIC][1]-like markup
language for diagrams in technical documentation.  Pikchr is
designed to be embedded in [fenced code blocks][2] of
Markdown (or in similar mechanisms in other markup languages)
to provide a convenient means of showing diagrams.

[1]: https://en.wikipedia.org/wiki/Pic_language
[2]: https://spec.commonmark.org/0.29/#fenced-code-blocks

For example, the diagram:

~~~~ pikchr indent
arrow; box "Hello, World!"; arrow
~~~~

Is generated using the following Markdown:

~~~~~~
   ~~~~ pikchr indent
   arrow; box "Hello, World!"; arrow
   ~~~~
~~~~~~

## Copyright

Zero-clause BSD

The Pikchr source code is a self-contained original work.  It has no
external dependencies apart from the standard C library and does not
use code taken from the internet or other external sources.  All of the Pikchr
source code is released under a zero-clause BSD license.  After being
processed using [Lemon][lemon], the Pikchr source code is a single
file of C89 named "`pikchr.c`".  These features
are designed to make Pikchr easy to integrate into other systems.

[lemon]: https://www.sqlite.org/lemon.html

## A Work In Progress

As of this writing (2020-09-09), Pikchr is a work-in-progress.
More documentation is forthcoming.  We want to use Pikchr to write
the Pikchr documentation, but it order to do that, we first have
to deploy Pikchr into a working system ([Fossil][3] in this case)
and that means the initial deployment must be undocumented.
Volunteers are welcomed, of course.

[3]: https://fossil-scm.org/fossil

## Try It Out

  *  [](/pikchrshow)
  *  [Wiki Sandbox](/wikiedit?name=Sandbox)

## Internal Links (all documents are incomplete)

  *  [Pikchr User Manual](./doc/userman.md)
  *  [Pikchr Language Grammar](./doc/grammar.md)
  *  [Differences From PIC](./doc/differences.md)
  *  [Invoking Pikchr From Markdown](./doc/usepikchr.md)

## External Links

  *  [BWK paper on the original PIC](/uv/pic.pdf)
  *  [DPIC Documentation](/uv/dpic-doc.pdf)
  *  [ESR GnuPIC Docs](/uv/gpic.pdf)
