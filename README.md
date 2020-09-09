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

## A Work In Progress

As of this writing (2020-09-09), Pikchr is a work-in-progress.
More documentation is forthcoming.  We want to use Pikchr to write
the Pikchr documentation, but it order to do that, we first have
to deploy Pikchr into a working system ([Fossil][3] in this case)
and that means the initial deployment must be undocumented.
Volunteers are welcomed, of course.

[3]: https://fossil-scm.org/fossil

## Derivation From PIC

The inspiration for Pikchr is the venerable PIC language from
Bell Labs (circa early 1980s).  Pikchr is *mostly*
compatible with PIC, though Pikchr has many extensions, and
it omits some legacy-PIC features (such as the "sh" command)
that would be a security issue in internet-facing software.  Most of the
example PIC scripts contained in the [PIC User Manual][4] work
fine with Pikchr, perhaps with a few minor tweaks.  For example:

~~~~ pikchr center
        margin = 5mm;

        circle "DISK"
        arrow "character" "defns" right 150%
CPU:    box "CPU" "(16-bit mini)"
        /*{*/ arrow <- from top of CPU up "input " rjust /*}*/
        arrow right from CPU.e
CRT:    "   CRT" ljust wid 1px
        line from CRT - 0,0.075 up 0.15 \
                then right 0.5 \
                then right 0.5 up 0.25 \
                then down 0.5+0.15 \
                then left 0.5 up 0.25 \
                then left 0.5
Paper:  CRT + 1.05,0.75
        arrow <- from Paper down 1.5
        " ...  paper" ljust at end of last arrow + 0, 0.25
        circle rad 0.05 at Paper + (-0.055, -0.25)
        circle rad 0.05 at Paper + (0.055, -0.25)
        "   rollers" ljust at Paper + (0.1, -0.25)
~~~~

PIC and Pikchr are sufficiently similar that you can get started using
Pikchr by reading the PIC user manual.

See the [raw Markdown source text to this page][5] to see more
examples.


[4]: http://doc.cat-v.org/unix/v8/picmemo.pdf
[5]: /doc/trunk/README.md?mimetype=text/plain
