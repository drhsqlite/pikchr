# How Pikchr Is Used To Generate SQLite Syntax Diagrams.

Beginning with SQLite version 3.34.0, the graphical
[syntax diagrams][1] in the SQLite documentation are SVG generated
using Pikchr.  Previously the diagrams where GIF images generated
using Tcl/Tk, ghostscript, and imagemagick.

[1]: https://sqlite.org/draft/syntaxdiagrams.html

## Advantages To The New Approach

  *  The SVG syntax diagrams are embedded in the text of the
     HTML documentation pages, rather than being separately loaded
     GIF images.  That means fewer round-trips to the server to fetch
     resources, and the HTML documentation pages can be saved to a
     file and reloaded later for viewing off-line.

  *  SVG is resolution independent, so that diagrams look better on
     mobile devices.

  *  The Pikchr source text promises to be easier to maintain than
     the older Tcl/Tk+ghostscript+imagemagick hodge-podge.

  *  The scripts used to convert the documentation source text into
     display-ready HTML can now be cross-platform.  The prior approach
     only seemed to work on Linux, and then only if the right utilities
     were installed.

  *  Pikchr provides additional flexibility in the formatting of
     syntax digrams, so that the diagrams can be made easier to read
     and understand.

## How It Works

The SQLite documentation is generated using TCL.

SQLite documentation source files are combinations HTML and TCL.
The source documents are initially HTML, but any
text between `<tcl>`...`</tcl>` is executed as TCL script.
There are also other special features such as enhanced hyperlinks
and some special markup styles.
A [TCL script][2] is run over the source text that evaluates the
embedded TCL and other special feathres and then outputs the pure 
HTML documentation pages.

[2]: https://sqlite.org/docsrc/file/wrap.tcl

Each syntax diagram is a file in the
[art/syntax/][3] subdirectory of the [documentation source repository][4].
You can click on [any of the Pikchr source files][3] to see the corresponding
diagram.  Click on the "Text" submenu option to see the original Pikchr
source text rather than the rendered SVG.

[3]: https://www.sqlite.org/docsrc/dir/art/syntax?ci=trunk
[4]: https://www.sqlite.org/docsrc/doc/trunk/README.md

### Pikchr As A TCL Extension

The pikchr.c source file can be compiled into a TCL extension by
adding the -DPIKCHR_TCL compile-time option.  As a TCL extensions,
Pikchr provides a single new TCL command named "`pikchr`" which takes
a single argument that the Pikchr source text.  The `pikchr` command returns
a TCL list of three elements which are:

   1.  The SVG output text
   2.  The width of the output in pixels
   3.  The height of the output in pixels

As with ordinary Pikchr, a negative width is returned if the input text
contains an error, and the output text is the error message.

### Automatic Insertion Of Diagrams Into Documentation

Within the SQLite documentation source text, markup of the following
form causes the named Pikchr syntax diagram to be loaded, converted
into SVG, and the output SVG added to the documentation under construction:

~~~~
   <tcl>
   RecursiveBubbleDiagram expr
   </tcl>
~~~~

The RecursiveBubbleDiagram TCL procedure uses the "`pikchr`" TCL command
to convert the Pikchr source text into SVG and inserts that SVG.  The
command also looks for other diagrams that are referenced by that diagram
and loads them as well, together with appropriate javascript to cause the
sub-diagrams to be initially hidden, but to expand when the read clicks on
the appropriate links.
