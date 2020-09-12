# Pikchr User Manual

## Introduction

This is a guide to generating diagrams using Pikchr
(pronounced "Picture").  This guide is
designed to teach you to use Pikchr.  It is not a reference for the
Pikchr language (that is a separate document) nor is it an explanation
of why you might want to use Pikchr.  The goal here is to provide
a practical and accessible tutorial on using Pikchr.

## Running Pikchr Scripts

The original goal of Pikchr is to embed diagrams into Markdown or other
simple markup languages.  The details on how to do that are covered
separately.  For the purpose of this tutorial, we will only write
pure Pikchr scripts without the surrounding markup.  To experiement
with Pikchr, visit the [](/pikchrshow) page on the website hosting
this document (preferrably in a separate window).  Type in the following
script and press the Preview button:
<a id="firstdemo"></a>

~~~~~
     line; box "Hello," "World!"; arrow
~~~~~

If you do this right, the output should appear as:

~~~~~ pikchr center
     line; box "Hello," "World!"; arrow
~~~~~

So there you go: you've created and rendered your first diagram using
Pikchr!  You will do well to keep that /pikchrshow screen handy, in a
separate browser window, so that you can try out scripts as you proceed
through this tutoral.

## About Pikchr Scripts

The structure of a Pikchr script is very simple.  A Pikchr script is
just a sequence of Pikchr statements, separated by either new-lines or
semicolons.  The "Hello, world!" example above used three statements,
a "line", a "box", and an "arrow", each separated by semicolons.

Whitespace (other than newlines) and comments are ignored.  Comments in
pikchr can be in the style of TCL, C, or C++.  That is to say, comments
consist of a "`#`" or "`//`"  and include all characters up to but
not including the next new-line, or all text
in between "`/*`" and the first following "`*/`".
The example script above could be rewritten with each statement on
a separate line, and with comments describing what each statement is
doing:

~~~~~
    # The first component of the drawing is a line
    line
    // The second component is a box with text "Hello, World!"
    box "Hello," "World!"
    /* Finally an arrow */
    arrow
~~~~~

Remember that new-lines separate statements.  If you have a long statement
that needs to be split into multiple lines, escape the newline with
a backslash character and the new-line will be treated as any other space:

~~~~~
    line
    box \
       "Hello," \
       "World!"
    arrow
~~~~~

So, a Pikchr script is just a list of statements.  But what is a statement?

## Pikchr Statements

*Most* statements are descriptions of a single graphic object that
becomes part of the diagram.  The first token of the statement is the
object class-name.  The following classes are currently supported:

~~~~~ pikchr center
box "box"
circle "circle" at 1 right of previous
ellipse "ellipse" at 1 right of previous
oval "oval" at .8 below first box
cylinder "cylinder" at 1 right of previous
file "file" at 1 right of previous
line "line" above from .8 below last oval.w
arrow "arrow" above from 1 right of previous
spline from previous+(1.8cm,-.2cm) \
   go right .15 then .3 heading 30 then .5 heading 160 then .4 heading 20 \
   then right .15
"spline" at 3rd vertex of previous
dot at .6 below last line
text "dot" with .s at .2cm above previous.n
arc from 1 right of previous dot
text "arc" at (previous.start, previous.end)
text "text" at 1.3 right of start of previous arc
~~~~~

A statement can be only the class-name and nothing else.  But the class-name
is usually followed by one or more "attributes".  Attributes are used
to modify the appearance of the object, or to position the object relative
to prior objects.

So to revisit the ["Hello, World" demonstration script above](#firstdemo),
we see that that script contains three object descriptions:

  1.  A "line" object with no attributes (meaning that the line is shown
      with no changes to its default appearance).
  2.  A "box" object with two string literal attributes.  The string
      literal attributes cause the corresponding strings to be drawn
      inside the box.
  3.  An "arrow" object with no attributes.

## Layout

By default, objects are stacked beside each other from left to right.
The Pikchr layout engine keeps track of the "layout direction" which
can be one of "right", "down", "left", or "right".  The layout direction
defaults to "right".  But you can change it using a statement which
consists of just the name of the new direction.  So, for example,
if we insert the "down" statement in front of our test script, like
this:

~~~~~
    down
    line
    box  "Hello,"  "World!"
    arrow
~~~~~

Then the objects are stacked moving downward:

~~~~~ pikchr center
    down
    line
    box  "Hello,"  "World!"
    arrow
~~~~~

Or, you can change the layout direction to "left":

~~~~~ pikchr center
    left
    line
    box  "Hello,"  "World!"
    arrow
~~~~~

Or to "up":

~~~~~ pikchr center
    up
    line
    box  "Hello,"  "World!"
    arrow
~~~~~
