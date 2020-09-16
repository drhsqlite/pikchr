# Pikchr User Manual

 <!--markdown-paragraph-numbers-->

# Introduction

This is a guide to generating diagrams using Pikchr
(pronounced "Picture").  This guide is
designed to teach you to use Pikchr.  It is not a reference for the
Pikchr language (that is a [separate document][gram]) nor is it an explanation
of why you might want to use Pikchr.  The goal here is to provide
a practical and accessible tutorial on using Pikchr.

[gram]: ./grammar.md

# Running Pikchr Scripts

The design goal of Pikchr is to enabled embedded line diagrams in Markdown or other
simple markup languages.  The details on how to embedded Pikchr in Markdown is
[covered separately][embed].  For the purpose of this tutorial, we will only write
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

[embed]: ./usepikchr.md

# About Pikchr Scripts

Pikchr is designed to be simple.  A Pikchr script is
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

# Pikchr Statements

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

# Layout

By default, objects are stacked beside each other from left to right.
The Pikchr layout engine keeps track of the "layout direction" which
can be one of "right", "down", "left", or "up".  The layout direction
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

It is common to stack line objects (lines, arrows, splines) against
block objects (boxes, circles, ovals, etc.), but this is not required.
You can stack a bunch of block objects together.
For example:

~~~~~
    box; circle; cylinder
~~~~~

Yields:

~~~~~ pikchr center
    box; circle; cylinder
~~~~~

More often, you want to put space in between the block objects.
The special "move" object exists for that purpose.  Consider:

~~~~~
    box; move; circle; move; cylinder
~~~~~

This script creates the same three block objects but also inserts some "moves"
to add whitespace between them:

~~~~~ pikchr center
    box; move; circle; move; cylinder
~~~~~

Implementation note:  A "move" is really just an invisible "line".  So
the following script generates the same output as the previous.
([Try it!](/pikchrshow?content=box;line%20invisible;circle;line%20invisible;cylinder))

~~~~~
    box; line invisible; circle; line invisible; cylinder
~~~~~

# Controlling Layout Using Attributes

The automatic stacking of objects is convenient in many cases.  But
most diagrams will want some objects placed somewhere other than
immediately adjacent to their predecessor.  For that reason, layout
attributes are provided that allow precise placement of objects.

To see how this works, consider the previous example of a box, circle,
and cylinder separated by some space.  Suppose we want to draw an arrow
that goes downward out of the box, then right, then up into the
cylinder.  The complete script might look something like this:

~~~~~
    box; move; circle; move; cylinder
    arrow from first box.s \
          down 1cm \
          then right until even with first cylinder \
          then to first cylinder.s
~~~~~

This script results in the following diagram:


~~~~~ pikchr center
    box; move; circle; move; cylinder
    arrow from first box.s \
          down 1cm \
          then right until even with first cylinder \
          then to first cylinder.s
~~~~~

That is indeed the image we want, but there are a lot of words on
that "arrow" statement!  Don't panic, though.  It's actually pretty
simple.  We'll take it apart and explain it piece by piece.

First note that the "arrow" statement is broken up into four separate
lines of text, with a "`\`" at the end of the first three lines to
prevent the subsequent new-line from prematurely closing the statement.
Splitting up the arrow into separate lines this way is purely for
human readability.  If you are more comfortable putting the whole
statement on one line, that is fine too.  Pikchr doesn't care.  Just
be sure to remember the backslashes if you do split lines!

The attributes on the "arrow" statement describe the path taken by
the arrow.  The first attribute is "`from first box.s`".  This "from"
attribute specifies where the arrow starts.  In this case, it starts
at the "s" (or "south") corner of the "first box".  The "first box"
part is probably self explanatory.  (You can also write it as
"1st box" instead of "first box", and in fact legacy-PIC requires
the use of "1st" instead of "first".)  But what is the ".s" part?

Every block object has eight points on its perimeter that are named
for compass points.   Like this:

~~~~~ pikchr center
A: box
dot color red at A.nw ".nw " rjust above
dot same at A.w ".w " rjust
dot same at A.sw ".sw " rjust below
dot same at A.s ".s" below
dot same at A.se " .se" ljust below
dot same at A.e " .e" ljust
dot same at A.ne " .ne" ljust above
dot same at A.n ".n" above
dot same at A.c " .c" ljust
A: circle at 1.5 right of A
dot color red at A.nw ".nw " rjust above
dot same at A.w ".w " rjust
dot same at A.sw ".sw " rjust below
dot same at A.s ".s" below
dot same at A.se " .se" ljust below
dot same at A.e " .e" ljust
dot same at A.ne " .ne" ljust above
dot same at A.n ".n" above
dot same at A.c " .c" ljust
A: cylinder at 1.5 right of A
dot color red at A.nw ".nw " rjust above
dot same at A.w ".w " rjust
dot same at A.sw ".sw " rjust below
dot same at A.s ".s" below
dot same at A.se " .se" ljust below
dot same at A.e " .e" ljust
dot same at A.ne " .ne" ljust above
dot same at A.n ".n" above
dot same at A.c " .c" ljust
~~~~~

As you can see, there is also a point in the middle called ".c".
Every block object has these compass points and you can refer to them
when positioning the object itself, or when positioning other objects
relative to the block object.  In this case, we are starting the
arrow at the ".s" corner of the box.

The next phrase on the "arrow" statement is "`down 1cm`".  As you
might guess, this phrase causes the arrow to move downward from its
previous position (its starting point) by 1 centimeter.  This phrase
highlights a key enhancement of Pikchr over legacy-PIC.  Legacy-PIC
did everything in inches only.  No units were allowed.  Pikchr allows
you to attach units to measurements, as in this case where it is
"1cm".  Internally, Pikchr still keeps track of everything in inches
(for compatibility with PIC).  The "1cm" token is really just an
alternative spelling for the numeric constant "0.39370078740157480316"
which is the inch-equivalent of 1 centimeter.  Surely you agree that
"1cm" is much easier to read and write!  Other units recognized by Pikchr
are "px" for pixels, "pt" for points, "pc" for picas, "mm" for millimeters,
and of course "in" for inches.  Inches are assumed if no units are
specified.

Back to our arrow:  We have now established a path for the arrow
down 1 centimeter from the ".s" corner of the box.  The next phrase
is:  "`then right until even with first cylinder`".
You can perhaps guess that this means that the arrow should continue
to the right until it is lined up below the first cylinder.  You,
the diagram designer, don't know (and don't really want to know)
how far apart the box and the cylinder are, so you can't tell it
exactly how far to go.  This phrase is a convenient way of telling
Pikchr to "make the line long enough".

Note that the "`first cylinder`" part of the "until even with"
phrase is actually an abbreviation for "`first cylinder.c`" - the
center of the cylinder.  This is what we want.  You could also
write "`first cylinder.s`" if you want.

The "until even with" phrase is not found in legacy-PIC.  In that
system, you would have to do some extra math to figure out the
distance for yourself.  Perhaps something like:
"`then right (1st cylinder.s.x - 1st box.s.x)`".  We think the
"until even with" phrase is easier to use and understand.

The final phrase in the "arrow" statement is
"`then to first cylinder.s`".  This phrase tells the arrow to go
from whereever it is at the moment, directly to the ".s" corner
of the cylinder.

# The Advantage Of Relative Layout

Notice that our sample diagram contains no coordinates and only
one hard-coded distance (the "down 1cm" in the arrow).  The script
is written in such a way that the script-writer does not have
to do a lot of distance calculation.  The layout compensates
automatically.

For example, so suppose you come back to this script later and
decide you need to insert an ellipse in between the circle and
the cylinder.  This is easily accomplished:

~~~~~
    box; move; circle; move; ellipse; move; cylinder
    arrow from first box.s \
          down 1cm \
          then right until even with first cylinder \
          then to first cylinder.s
~~~~~

We simply add the ellipse (and an extra "move") on the first line.
Even though the coordinate positions of the objects have adjusted,
the description of the arrow that connects the box to the
cylinder is not based on coordinates or absolute distances and
so it does not have to change at all.  Pikchr will
compensate automatically:

~~~~~ pikchr center
    box; move; circle; move; ellipse; move; cylinder
    arrow from first box.s \
          down 1cm \
          then right until even with first cylinder \
          then to first cylinder.s
~~~~~

Both Legacy-PIC and Pikchr allow you to specify hard-coded coordinates
and distances when laying out your diagram.  But you are encouraged
to avoid that approach.  Instead, place each new object you create
relative to the position of prior objects.
Pikchr provides many mechanisms for specifying the location
of each object in terms of the locations of its predecessors.  With
a little study of the syntax options available to you (and discussed
further below) you will be generating complex diagrams using Pikchr
in no time.

# Single-Pass Design

Both Pikchr and legacy-PIC operate on a single-pass design.  Objects
can refer to other objects that occur before them in the script, but not
to objects that occur later in the script.  Any computations that go
into placing an object occur as the object definition is parsed.  As soon
as the newline or semicolon that terminates the object definition is
reached, the size, location, and characteristics of the object are
fixed and cannot subsequently be altered.  (One exception:  sub-objects that
are part of a container (discussed later) are placed relative to the
origin of the container.  Their shape and locations relative to each
other are fixed, but their final absolute position is not fixed until
their container itself is fixed.)

The single-pass approach contributes to the conceptual simplicity of
Pikchr (and legacy-PIC).  There is no "solver" that has to work through
forward and backward layout constraints to find a solution.  This
simplicity of design helps to keep Pikchr scripts easy to write and
easy to understand.

# Names Of Objects

The previous example used the phrases like "`first box`" and "`first cylinder`"
to refer to particular objects.  There are many variations on this naming
scheme:

  *  "`previous`" &larr; the previous object regardless of its class
  *  "`last circle`" &larr; the recently created circle object
  *  "`3rd last oval`" &larr; the antipenultimate oval object
  *  "`17th ellipse`" &larr; the seventeenth ellipse object
  *  ... and so forth

This works, but it can be fragile.  If you go back later and insert a new
object in the stream, it can mess up your counts.  Or, for that matter,
you might just miscount.

In a complex diagram, if often works better to assign symbolic names to
objects.  Do this by putting the object name and a colon ("`:`") immediately
before the class-name in the object definition.  The object name must
begin with a capital letter.  Afterwards, the object can be referred to
by that name.

Consider how this simplifies our previous example:

~~~~~
    B1:  box; move;
         circle; move;
         ellipse; move;
    C1:  cylinder
         arrow from B1.s \
            down 1cm \
            then right until even with C1 \
            then to C1.s
~~~~~

By giving symbolic names to the box and cylinder, the arrow path
description is simplified.  Futhermore, if the ellipse gets changed
into another cylinder, the arrow still refers to the correct cylinder.
Note that the indentation of the lines following each symbolic name
above is syntacially unimportant - it serves only to improve human
readability.

# Layout Of Block Objects

For lines (and arrows and splines), you have to specify a path that the line
follows, a path that might involve multiple bends and turns.  Defining the location
of block objects is easier.  You just provide a single location to place
the object.  Ideally, you should place the object relative to some other
object, of course.

Let's say you have box and you want to position a circle 2 centimeters to the
right of that box.  You simply use an "`at`" attribute on the circle to tell it
to position itself 2 cm to the right of the box:

~~~~~
  B1: box
      circle at 2cm right of B1
~~~~~

The resulting diagram is:

~~~~~ pikchr center
  B1: box
      circle at 2cm right of B1

  X1: line thin color gray down 50% from 2mm south of B1.s
  X2: line same from (last circle.s,X1.start)
      arrow <-> thin from 3/4<X1.start,X1.end> right until even with X2 \
         "2cm" above color gray
      assert( last arrow.width == 2cm )
~~~~~

(Actually, I added a three more objects in order to show the dimension lines
in the diagram.  If you want to see the exact Pikchr code that generates any
of the diagrams in this user manual - and assuming you are viewing this user
manual from [Fossil][fossil] and that you are using a web browser with
javascript enabled - just click on the diagram.)

[fossil]: https://fossil-scm.org/

The circle is positioned so that its *center* is 2 centimeters to the
right of the *center* of the box.  If what you really wanted is that the
left (or west) side of the circle is 2 cm to the of the right (or east) side
of the box, then just say so:

~~~~~
  B1: box
  C1: circle with .w at 2cm right of B1.e
~~~~~

Normally at "`at`" clause will set the center of an object.  But if
you add a "`with`" prefix you can specify to use any other boundary
point of the object to be the reference for positioning.  The Pikchr
script above is saying "make the C1.w point be 2 cm right of B1.e".
And we have:

~~~~~ pikchr center
  B1: box
  C1: circle with .w at 2cm right of B1.e

  X1: line thin color gray down 50% from 2mm south of B1.se
  X2: line same from (C1.w,X1.start)
      arrow <-> thin from 3/4<X1.start,X1.end> right until even with X2 \
         "2cm" above color gray
      assert( last arrow.width == 2cm )
~~~~~

That's the whole story behind positioning block objects on a diagram.
You just add an attribute of the form:

>  **with** *reference-point* **at** *position*

And Pikchr will place the specified reference-point of the object at
*position*.  If you omit the "`with`" clause, the center of the
object ("`.c`") is used as the *reference-point*.  The power of Pikchr
comes from the fact that "*position*" can be a rather complex expression.
The previous example used a relatively simple *position*
of "`2cm right of B1.e`".  That was sufficient for our simple diagram.
More complex diagrams can have move complex *position* phrases.

## Automatic Layout Of Block Objects

If you omit the "`at`" attribute from a block object, the object is positioned
as if you had used the following:

>  `with .start at previous.end`

Except, the very first object in the script has no "previous" and so it
is positioned using:

>  `with .c at (0,0)`

Let's talk little more about the usual case:
"`with .start at previous.end`".  The "`previous`" keyword means the
previous object in the script.  (You can also use the keyword "`last`"
for this purpose.)  So we are positioning the current object relative
to the previous object.  But what about the ".start" and ".end".

Remember that every object has 8 boundary points whose names correspond
to compass directions:  ".n", ".ne", ".e", ".se", ".s", ".sw", ".w",
and ".nw", plus the center point ".c".  The ".start" and ".end" are also
boundary points, but their position varies depending on the
layout direction that is current when the object is created.

<blockquote>
<table border="1" cellpadding="10px" cellspacing="0">
<tr><th>Layout Direction<th>.start<th>.end
<tr><td>right<td>.w<td>.e
<tr><td>down<td>.n<td>.s
<tr><td>left<td>.e<td>.w
<tr><td>up<td>.s<td>.n
</table></blockquote>

Recall the earlier example that consisted of three objects stacked
together:

~~~~~
    right; box; circle; cylinder
~~~~~

(I added an "`right`" at the beginning to make the layout direction
clear, but as "right" is the default layout direction, it doesn't change
anything.)

Armed with our new knowledge of how "`at`"-less block objects are
positioned, we can better understand what is going on.  The box is
the first object.  It gets positioned with its center at (0,0), which
we can show by putting a red dot at (0,0):

~~~~~
    right; box; circle; cylinder
    dot color red at (0,0)
~~~~~

~~~~~ pikchr
    right; box; circle; cylinder
    dot color red at (0,0)
~~~~~

Because the layout direction is "right", the start and end of the box
are the .w and .e boundary points.  Prove this by putting more colored dots
at those points and rendering the result:

~~~~~
    right; box; circle; cylinder
    dot color green at 1st box.start
    dot color blue at 1st box.end
~~~~~

~~~~~ pikchr
    right; box; circle; cylinder
    dot color green at 1st box.start
    dot color blue at 1st box.end
~~~~~

Similarly, we can show that the .start and .end of the circle are its
.w and .e boundary points.  (Add new color dots to prove this to yourself
if you like.)  And clearly, the .start of the circle is directly on top
of the .end of the box.

Now consider what happens if we change the layout direction after the
circle is created but before the cylinder is created:

~~~~~
    right; box; circle; down; cylinder
~~~~~

This script works a little differently on Pikchr than it does on PIC.
The change in behavior is deliberate, because we feel that the Pikchr
approach is better.  On PIC, the diagram above would be rendered
like this:

~~~~~ pikchr
    right; box; circle; cylinder with .n at previous.e
~~~~~

But on Pikchr the placement of the cylinder is different:

~~~~~ pikchr
    right; box; circle; cylinder with .n at previous.s
~~~~~

Let's take apart what is happening here.  In both systems, after
the "circle" object has been parsed and positioned, the .end of
the circle is the same as .e, because the layout direction is "right".
If we omit the "down" and "cylinder" and draw a dot at the ".end" of
circle to show where it is, we can see this:

~~~~~ pikchr
    right; box; circle
    dot color red at last circle.end
~~~~~

The next statement is "down".  The "down" statement changes the layout
direction to "down" in both systems.  In legacy PIC the .end of the circle
remains at the .e boundary.  Then when the "cylinder" is positioned,
its ".start" is at .n because the layout direction is now "down"
and so the .n point of the cylinder is aligned to the .e point of
the circle.

Pikchr works like PIC with on important change.  When the "down" statement
is evaluated, Pikchr also moves the ".end" of the previous object
to a new location that is approprate for the new direction.  So, in other
words, the down command move the .end of the circle from .e to .s.
You can see this by setting a red dot at the .end of
the circle *after* the "down" command:

~~~~~ pikchr
    right; box; circle; down
    dot color red at first circle.end
~~~~~

Or, we can "`print`" the coordinates of the .end of the circle before
and after the "down" command as see that they shift:

~~~~~ pikchr
    right; box; C1: circle
    print "before: ", C1.end.x, ", ", C1.end.y
    down
    print "after: ", C1.end.x, ", ", C1.end.y
~~~~~
