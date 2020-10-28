# Pikchr User Manual

# Introduction

This is a guide to generating diagrams using Pikchr
(pronounced "Picture").  This guide is
designed to teach you to use Pikchr.  It is not a reference for the
Pikchr language (that is a [separate document][gram]) nor is it an explanation
of why you might want to use Pikchr.  The goal here is to provide
a practical and accessible tutorial on using Pikchr.

[gram]: ./grammar.md

# Running Pikchr Scripts

The design goal of Pikchr is to enable embedded line diagrams in Markdown or other
simple markup languages.  The details on how to embedded Pikchr in Markdown is
[covered separately][embed].  For the purpose of this tutorial, we will only write
pure Pikchr scripts without the surrounding markup.  To experiment
with Pikchr, visit the [](/pikchrshow) page on the website hosting
this document (preferably in a separate window).  Type in the following
script and press the Preview button:
<a id="firstdemo"></a>

~~~~~ pikchr source toggle indent
     line; box "Hello," "World!"; arrow
~~~~~

If you do this right, the output should appear as:

~~~~~ pikchr toggle indent
     line; box "Hello," "World!"; arrow
~~~~~

So there you go: you've created and rendered your first diagram using
Pikchr!  You will do well to keep that /pikchrshow screen handy, in a
separate browser window, so that you can try out scripts as you proceed
through this tutorial.

[embed]: ./usepikchr.md

# Viewing Pikchr Script Source Code For This Document

For this particular document, you can click on any of the diagrams
rendered by Pikchr and the display will convert to showing you the
original Pikchr source text.  Click again to go back to seeing the
rendered diagram.

The click-to-change-view behavior is a property of this one
particular document and is not a general capability of Pikchr. On
other documents containing Pikchr diagrams that are generated using Fossil
you can use ctrl-click (alt-click on Macs) to toggle the view.
That is, click on the diagram while holding down the Ctrl key or the Alt key.
This is not possible if
you are on a tablet or phone, since you don't have a Ctrl or Alt key to hold
down there.  Other systems might not implement the view-swapping behavior
at all.  This is a platform-depending feature that is one layer above
Pikchr itself.

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

~~~~~ pikchr source toggle indent
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

~~~~~ pikchr source toggle indent
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

~~~~~ pikchr toggle indent
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
defaults to "right", but you can change it using a statement which
consists of just the name of the new direction.  So,
if we insert the "down" statement in front of our test script, like
this:

~~~~~ pikchr source toggle indent
    down
    line
    box  "Hello,"  "World!"
    arrow
~~~~~

Then the objects are stacked moving downward:

~~~~~ pikchr toggle indent
    down
    line
    box  "Hello,"  "World!"
    arrow
~~~~~

Or, you can change the layout direction to "left":

~~~~~ pikchr toggle indent
    left
    line
    box  "Hello,"  "World!"
    arrow
~~~~~

Or to "up":

~~~~~ pikchr toggle indent
    up
    line
    box  "Hello,"  "World!"
    arrow
~~~~~

It is common to stack line objects (lines, arrows, splines) against
block objects (boxes, circles, ovals, etc.), but this is not required.
You can stack a bunch of block objects together.
For example:

~~~~~ pikchr source toggle indent
    box; circle; cylinder
~~~~~

Yields:

~~~~~ pikchr toggle indent
    box; circle; cylinder
~~~~~

More often, you want to put space in between the block objects.
The special "move" object exists for that purpose.  Consider:

~~~~~ pikchr source toggle indent
    box; move; circle; move; cylinder
~~~~~

This script creates the same three block objects but with 
whitespace in between them:

~~~~~ pikchr toggle indent
    box; move; circle; move; cylinder
~~~~~

Implementation note:  A "move" is really just an invisible "line".  So
the following script generates the same output as the previous.
([Try it!](/pikchrshow?content=box;line%20invisible;circle;line%20invisible;cylinder))

~~~~~ pikchr source toggle indent
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

~~~~~ pikchr source toggle indent
    box; move; circle; move; cylinder
    arrow from first box.s \
          down 1cm \
          then right until even with first cylinder \
          then to first cylinder.s
~~~~~

This script results in the following diagram:


~~~~~ pikchr toggle indent
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

~~~~~ pikchr toggle indent
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
highlights a key enhancement of Pikchr over legacy-PIC.  PIC does (or did)
everything in inches only.  No units were allowed.  Pikchr allows
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
from wherever it is at the moment, directly to the ".s" corner
of the cylinder.

# The Advantage Of Relative Layout

Notice that our sample diagram contains no coordinates and only
one hard-coded distance (the "down 1cm" in the arrow).  The script
is written in such a way that the script-writer does not have
to do a lot of distance calculation.  The layout compensates
automatically.

For example, suppose you come back to this script later and
decide you need to insert an ellipse in between the circle and
the cylinder.  This is easily accomplished:

~~~~~ pikchr source toggle indent
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

~~~~~ pikchr toggle indent
    box; move; circle; move; ellipse; move; cylinder
    arrow from first box.s \
          down 1cm \
          then right until even with first cylinder \
          then to first cylinder.s
~~~~~

Both PIC and Pikchr allow you to specify hard-coded coordinates
and distances when laying out your diagram.  But you are encouraged
to avoid that approach.  Instead, place each new object you create
relative to the position of prior objects.
Pikchr provides many mechanisms for specifying the location
of each object in terms of the locations of its predecessors.  With
a little study of the syntax options available to you (and discussed
further below) you will be generating complex diagrams using Pikchr
in no time.

# Single-Pass Design

Both Pikchr and PIC operate on a single-pass design.  Objects
can refer to other objects that occur before them in the script, but not
to objects that occur later in the script.  Any computations that go
into placing an object occur as the object definition is parsed.  As soon
as the newline or semicolon that terminates the object definition is
reached, the size, location, and characteristics of the object are
fixed and cannot subsequently be altered.  (One exception:  sub-objects that
are part of a `[]`-container (discussed later) are placed relative to the
origin of the container.  Their shape and locations relative to each
other are fixed, but their final absolute position is not fixed until
the `[]`-container itself is fixed.)

The single-pass approach contributes to the conceptual simplicity of
Pikchr (and PIC).  There is no "solver" that has to work through
forward and backward layout constraints to find a solution.  This
simplicity of design helps to keep Pikchr scripts easy to write and
easy to understand.

# Names Of Objects

The previous example used the phrases like "`first box`" and "`first cylinder`"
to refer to particular objects.  There are many variations on this naming
scheme:

  *  "`previous`" &larr; the previous object regardless of its class
  *  "`last circle`" &larr; the most recently created circle object
  *  "`3rd last oval`" &larr; the antipenultimate oval object
  *  "`17th ellipse`" &larr; the seventeenth ellipse object
  *  ... and so forth

This works, but it can be fragile.  If you go back later and insert a new
object in the stream, it can mess up your counts.  Or, for that matter,
you might just miscount.

In a complex diagram, it often works better to assign symbolic names to
objects.  Do this by putting the object name and a colon ("`:`") immediately
before the class-name in the object definition.  The object name must
begin with a capital letter.  Afterwards, the object can be referred to
by that name.

Consider how this simplifies our previous example:

~~~~~ pikchr source toggle indent
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
description is simplified.  Furthermore, if the ellipse gets changed
into another cylinder, the arrow still refers to the correct cylinder.
Note that the indentation of the lines following each symbolic name
above is syntactically unimportant - it serves only to improve human
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

~~~~~ pikchr source toggle indent
  B1: box
      circle at 2cm right of B1
~~~~~

The resulting diagram is:

~~~~~ pikchr toggle indent
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
left (or west) side of the circle is 2 cm to the right (or east)
of the box, then just say so:

~~~~~ pikchr source toggle indent
  B1: box
  C1: circle with .w at 2cm right of B1.e
~~~~~

Normally at "`at`" clause will set the center of an object.  But if
you add a "`with`" prefix you can specify to use any other boundary
point of the object to be the reference for positioning.  The Pikchr
script above is saying "make the C1.w point be 2 cm right of B1.e".
And we have:

~~~~~ pikchr toggle indent
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

~~~~~ pikchr source toggle indent
    right; box; circle; cylinder
~~~~~

(I added an "`right`" at the beginning to make the layout direction
clear, but as "right" is the default layout direction, it doesn't change
anything.)

Armed with our new knowledge of how "`at`"-less block objects are
positioned, we can better understand what is going on.  The box is
the first object.  It gets positioned with its center at (0,0), which
we can show by putting a red dot at (0,0):

~~~~~ pikchr source toggle indent
    right; box; circle; cylinder
    dot color red at (0,0)
~~~~~

~~~~~ pikchr toggle indent
    right; box; circle; cylinder
    dot color red at (0,0)
~~~~~

Because the layout direction is "right", the start and end of the box
are the .w and .e boundary points.  Prove this by putting more colored dots
at those points and rendering the result:

~~~~~ pikchr source toggle indent
    right; box; circle; cylinder
    dot color green at 1st box.start
    dot color blue at 1st box.end
~~~~~

~~~~~ pikchr toggle indent
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

~~~~~ pikchr source toggle indent
    right; box; circle; down; cylinder
~~~~~

This script works a little differently on Pikchr than it does on PIC.
The change in behavior is deliberate, because we feel that the Pikchr
approach is better.  On PIC, the diagram above would be rendered
like this:

~~~~~ pikchr toggle indent
    right; box; circle; cylinder with .n at previous.e
~~~~~

But on Pikchr the placement of the cylinder is different:

~~~~~ pikchr toggle indent
    right; box; circle; cylinder with .n at previous.s
~~~~~

Let's take apart what is happening here.  In both systems, after
the "circle" object has been parsed and positioned, the .end of
the circle is the same as .e, because the layout direction is "right".
If we omit the "down" and "cylinder" and draw a dot at the ".end" of
circle to show where it is, we can see this:

~~~~~ pikchr toggle indent
    right; box; circle
    dot color red at last circle.end
~~~~~

The next statement is "down".  The "down" statement changes the layout
direction to "down" in both systems.  In legacy PIC the .end of the circle
remains at the .e boundary.  Then when the "cylinder" is positioned,
its ".start" is at .n because the layout direction is now "down"
and so the .n point of the cylinder is aligned to the .e point of
the circle.

Pikchr works like PIC with one important change:  When the "down" statement
is evaluated, Pikchr also moves the ".end" of the previous object
to a new location that is appropriate for the new direction.  So, in other
words, the down command moves the .end of the circle from .e to .s.
You can see this by setting a red dot at the .end of
the circle *after* the "down" command:

~~~~~ pikchr toggle indent
    right; box; circle; down
    dot color red at first circle.end
~~~~~

Or, we can "`print`" the coordinates of the .end of the circle before
and after the "down" command to see that they shift:

~~~~~ pikchr toggle indent
    right; box; C1: circle
    print "before: ", C1.end.x, ", ", C1.end.y
    down
    print "after: ", C1.end.x, ", ", C1.end.y
~~~~~

## Adjusting The Size Of Block Objects

The size of every block object is controlled by three parameters:

  *  `width` (often abbreviated as `wid`)
  *  `height` (or `ht`)
  *  `radius` (or `rad`)

There is also a fourth convenience parameter:

  *  `diameter`

The `diameter` is always twice the radius. Setting the `diameter` automatically
changes the `radius` and setting the `radius` automatically changes the
`diameter.

Usually the meanings of these parameters are obvious.

~~~~ pikchr toggle indent
A: box thick
line thin color gray left 70% from 2mm left of A.nw
line same from 2mm left of A.sw
text "height" at (7/8<previous.start,previous.end>,1/2<1st line,2ndline>)
line thin color gray from previous text.n up until even with 1st line ->
line thin color gray from previous text.s down until even with 2nd line ->
X1: line thin color gray down 50% from 2mm below A.sw
X2: line thin color gray down 50% from 2mm below A.se
text "width" at (1/2<X1,X2>,6/8<X1.start,X1.end>)
line thin color gray from previous text.w left until even with X1 ->
line thin color gray from previous text.e right until even with X2 ->
~~~~

The `radius` parameter, however, sometimes has non-obvious meanings.
For example, on a box, the `radius` determines the rounding of corners:

~~~~ pikchr toggle indent
A: box thick rad 0.3*boxht
line thin color gray left 70% from 2mm left of (A.w,A.n)
line same from 2mm left of (A.w,A.s)
text "height" at (7/8<previous.start,previous.end>,1/2<1st line,2ndline>)
line thin color gray from previous text.n up until even with 1st line ->
line thin color gray from previous text.s down until even with 2nd line ->
X1: line thin color gray down 50% from 2mm below (A.w,A.s)
X2: line thin color gray down 50% from 2mm below (A.e,A.s)
text "width" at (1/2<X1,X2>,6/8<X1.start,X1.end>)
line thin color gray from previous text.w left until even with X1 ->
line thin color gray from previous text.e right until even with X2 ->
X3: line thin color gray right 70% from 2mm right of (A.e,A.s)
X4: line thin color gray right 70% from A.rad above start of X3
text "radius" at (6/8<X4.start,X4.end>,1/2<X3,X4>)
line thin color gray from (previous,X3) down 30% <-
line thin color gray from (previous text,X4) up 30% <-
~~~~

For a [cylinder object](./cylinderobj.md) the `radius` determines the
thickness of the end caps:

~~~~ pikchr toggle indent
A: cylinder thick rad 150%
line thin color gray left 70% from 2mm left of (A.w,A.n)
line same from 2mm left of (A.w,A.s)
text "height" at (7/8<previous.start,previous.end>,1/2<1st line,2ndline>)
line thin color gray from previous text.n up until even with 1st line ->
line thin color gray from previous text.s down until even with 2nd line ->
X1: line thin color gray down 50% from 2mm below (A.w,A.s)
X2: line thin color gray down 50% from 2mm below (A.e,A.s)
text "width" at (1/2<X1,X2>,6/8<X1.start,X1.end>)
line thin color gray from previous text.w left until even with X1 ->
line thin color gray from previous text.e right until even with X2 ->
X3: line thin color gray right 70% from 2mm right of (A.e,A.ne)
X4: line thin color gray right 70% from A.rad below start of X3
text "radius" at (6/8<X4.start,X4.end>,1/2<X3,X4>)
line thin color gray from (previous,X4) down 30% <-
line thin color gray from (previous text,X3) up 30% <-
~~~~

For a [file object](./fileobj.md) the `radius` determines the size of
the page fold-over in the upper-right corner:

~~~~ pikchr toggle indent
A: file thick rad 100%
line thin color gray left 70% from 2mm left of (A.w,A.n)
line same from 2mm left of (A.w,A.s)
text "height" at (7/8<previous.start,previous.end>,1/2<1st line,2ndline>)
line thin color gray from previous text.n up until even with 1st line ->
line thin color gray from previous text.s down until even with 2nd line ->
X1: line thin color gray down 50% from 2mm below (A.w,A.s)
X2: line thin color gray down 50% from 2mm below (A.e,A.s)
text "width" at (1/2<X1,X2>,6/8<X1.start,X1.end>)
line thin color gray from previous text.w left until even with X1 ->
line thin color gray from previous text.e right until even with X2 ->
X3: line thin color gray right 70% from 2mm right of (A.e,A.n)
X4: line thin color gray right 70% from A.rad below start of X3
text "radius" at (6/8<X4.start,X4.end>,1/2<X3,X4>)
line thin color gray from (previous,X4) down 30% <-
line thin color gray from (previous text,X3) up 30% <-
~~~~

For a [circle object](./circleobj.md), the width and height and diameter
are always the same and the radius is always half the diameter.  Changing
any parameter automatically adjusts the other three.

~~~~ pikchr toggle indent
A: circle thick rad 120%
line thin color gray left 70% from 2mm left of (A.w,A.n)
line same from 2mm left of (A.w,A.s)
text "height" at (7/8<previous.start,previous.end>,1/2<1st line,2ndline>)
line thin color gray from previous text.n up until even with 1st line ->
line thin color gray from previous text.s down until even with 2nd line ->
X1: line thin color gray down 50% from 2mm below (A.w,A.s)
X2: line thin color gray down 50% from 2mm below (A.e,A.s)
text "width" at (1/2<X1,X2>,6/8<X1.start,X1.end>)
line thin color gray from previous text.w left until even with X1 ->
line thin color gray from previous text.e right until even with X2 ->
X3: line thin color gray right 70% from 2mm right of (A.e,A.s)
X4: line thin color gray right 70% from A.rad above start of X3
text "radius" at (6/8<X4.start,X4.end>,1/2<X3,X4>)
line thin color gray from (previous,X3) down 30% <-
line thin color gray from (previous text,X4) up 30% <-
line thin color gray <-> from A.sw to A.ne
line thin color gray from A.ne go 0.5*A.rad ne then 0.25*A.rad east
text " diameter" ljust at end of previous line
~~~~

Even though they are curvy objects, the `radius` (and hence `diameter`)
has no effect on [ellipse](./ellipseobj.md) and [oval](./ovalobj.md) objects.
The size of those objects is determined purely by their width and height:

~~~~ pikchr toggle indent
A: ellipse thick
line thin color gray left 70% from 2mm left of (A.w,A.n)
line same from 2mm left of (A.w,A.s)
text "height" at (7/8<previous.start,previous.end>,1/2<1st line,2ndline>)
line thin color gray from previous text.n up until even with 1st line ->
line thin color gray from previous text.s down until even with 2nd line ->
X1: line thin color gray down 50% from 2mm below (A.w,A.s)
X2: line thin color gray down 50% from 2mm below (A.e,A.s)
text "width" at (1/2<X1,X2>,6/8<X1.start,X1.end>)
line thin color gray from previous text.w left until even with X1 ->
line thin color gray from previous text.e right until even with X2 ->
~~~~

~~~~ pikchr toggle indent
A: oval thick
X0: line thin color gray left 70% from 2mm left of (A.w,A.n)
X1: line same from 2mm left of (A.w,A.s)
text "height" at (7/8<previous.start,previous.end>,1/2<X0,X1>)
line thin color gray from previous text.n up until even with X0 ->
line thin color gray from previous text.s down until even with X1 ->
X2: line thin color gray down 50% from 2mm below (A.w,A.s)
X3: line thin color gray down 50% from 2mm below (A.e,A.s)
text "width" at (1/2<X2,X3>,6/8<X2.start,X2.end>)
line thin color gray from previous text.w left until even with X2 ->
line thin color gray from previous text.e right until even with X3 ->

A: oval thick wid A.ht ht A.wid at 2.0*A.wid right of A
X0: line thin color gray left 70% from 2mm left of (A.w,A.n)
X1: line same from 2mm left of (A.w,A.s)
text "height" at (7/8<previous.start,previous.end>,1/2<X0,X1>)
line thin color gray from previous text.n up until even with X0 ->
line thin color gray from previous text.s down until even with X1 ->
X2: line thin color gray down 50% from 2mm below (A.w,A.s)
X3: line thin color gray down 50% from 2mm below (A.e,A.s)
text "width" small at (1/2<X2,X3>,6/8<X2.start,X2.end>)
line thin color gray from previous text.w left until even with X2 ->
line thin color gray from previous text.e right until even with X3 ->
~~~~

Notice that with an oval object, the semicircular end-cap is always
on the narrow end of the object.  In the default configuration where
the height is less than the width, the semicircular end-caps are on the
left and right, but if the width and height are modified so that the
width is less than the height, then semicircles appear on the top and
bottom instead.


### Default Sizes

Block objects have default sizes which are determined by variables.
For example, the width of a box is initialized the value of the `boxwid`
variable, which defaults to `0.75in`.

It is common for Pikchr scripts
to change these default at or near the beginning of a script in order to adjust
the default sizes of objects defined within that script.

### Setting Sizes Using Attributes

Use the "`width`" (or "`wid`") attribute to change the width of an object.
The argument to this attribute can be an expression (such as "`1cm`" or
"`0.75*boxwid`") or it can be a percentage of the prior value
(example: "`75%`").  This also works for "`height`" (or "`ht`"),
"`radius`" (or "`rad`"), and "`diameter`".

### Automatic Sizing To Fit Text Annotations

If a block object contains text annotations, the "`fit`" attribute causes
the width and height to be adjusted so that the object neatly encloses that
text.  The "`fit`" attribute only considers text that is previously defined
for the object, or in other words text annotations that occur to the left
of the "`fit`" keyword.  The width and height can be adjusted further after
the "`fit`" keyword, for example to provide a larger margin around the
text.  Click on the following script to see the difference that the
"`width 125%`" at the end of the second box definition makes.

~~~~ pikchr source toggle indent
    down
    box "Auto-fit text annotation" "as is" fit
    move 50%
    box "Auto-fix text annotation" "with 125% width" fit width 125%
~~~~

If a the end of a block object definition, either the width or height of the
object is less than or equal to zero, then that dimension is increased so as to
enclose all text annotations on the object.  Thus, for example, 
you can make all of the
boxes in your diagram auto-fit around their text annotations by prefacing
your script with something like:

~~~~ pikchr source toggle indent
    boxwid = 0; boxht = 0;
    box "Hello";
    move
    box "A longer label" "with multiple lines" "of label text"
~~~~

For all of these auto-fit features, Pikchr needs to know the dimensions of the
text annotations after rendering.  Unfortunately, that information is not
readily available, as Pikchr runs long before the generated SVG reaches the
web-browser in which it will be displayed.  Hence, Pikchr has to guess at the
text size.  Usually it does a good job of this, but it can be a little off,
especially for unusual (read: "non-ascii") characters or if the CSS for
the rendering environment sets a non-standard font face or font size.  To
compensate, the "`charwid`" and "`charht`" variables can be adjusted or
extra spaces can be added at the beginning or end of text strings.

These auto-fit features are a new innovation for Pikchr and are not available
in legacy PIC as far as we are aware.

## Attributes For Stroke-Width And Drawing Colors

Various attributes can be added to both block and line objects to influence
how the objects are drawn.

  *  `thickness` *dimension*
  *  `thick`
  *  `thin`
  *  `invisible` (or `invis`)
  *  `color` *color*
  *  `fill` *color*

The "`thickness`", "`thick`", "`thin`", and "`invisible`" attributes control
the stroke-width of the lines that construct an object.  The default stroke-width
for all objects is determined by the "`thickness`" variable which defaults
to "`0.015in`".  The "`thick`" and "`thin`" attributes increase or decrease
the stroke-width by a fixed percentages.  This attributes can be repeated
to make the stroke-width ever thicker or thinner.  The "`invisble`" attribute
simply sets the stroke-width to 0.

~~~~ pikchr toggle indent
   boxwid = 0
   boxht = 0
   right
   box "normal"
   move
   box "thin" thin
   move
   box "thick" thick
   move
   box "invisible" invisible
~~~~

The "`color`" and "`fill`" attributes change the foreground and background
colors of an object.  Colors can be expressed using any of the 140 standard
HTML color names, such as "Bisque" or "AliceBlue" or "LightGray".  Color
names are not case sensitive, so "bisque", "BISQUE", and "Bisque" all mean
the same thing.  Color names can also be expressed as an integer which is
interpreted as a 24-bit RGB value.  It is convenient to express numeric
color values using hexadecimal notation.  "Bisque" is the same as "0xffe4c4"
which is the same as "16770244".  

~~~~ pikchr toggle indent
   box "Color: CadetBlue" "Fill: Bisque" fill Bisque color CadetBlue fit
   move
   oval "Color: White" "Fill: RoyalBlue" color White fill ROYALBLUE fit
~~~~

Setting the "`fill`" to a negative number or "None" or "Off" makes the
background transparent.  That is the default.  The default foreground
color is black.

### Filled Polygons

The "`fill`" attribute does not affect the rendering of lines unless the
route of the line is terminated by the "`close`" attribute.  The "`close`"
keyword converts the line into a polygon.  Click to see the code:

~~~~ pikchr toggle indent
   line go 3cm heading 150 then 3cm west close \
                                      /* ^^^^^ nota bene! */ \
       fill 0x006000 color White "green" below "triangle" below
~~~~

Polygons are not required to have a fill color.  You can use the "`close`"
keyword to convert a polygon into a line and leave the background transparent.
But using "`fill` *color*" together with "`close`" is a common idiom.

## Text Annotations

Every object can have up to five lines of text annotation.  Each annotation
is a string literal attribute on the object definition.  By default, the
annotations are displayed around the center of the object, from top to bottom,
in the order that they appear in the input script.

~~~~ pikchr toggle indent
   box "box containing" "three lines" "of text" fit
   move
   arrow "Labeled" "line" wid 200%
~~~~

The layout and font style of the annotations can be modified using keywords
that appear after each string literal.  The following modifiers are supported:

  * **above**
  * **aligned**
  * **below**
  * **big**
  * **bold**
  * **center**
  * **italic**
  * **ljust**
  * **rjust**
  * **small**

### Position Text Above Or Below The Center Of The Object

The "`above`" and "`below`" keywords control the location of the
text above or below the center point of the object with which
the text is associated.  If there is just one text on the object
and the "`above`" and "`below`" keywords are omitted, the text is
placed directly over the center of the object.  This causes
the text to appear in the middle of lines:

~~~~ pikchr indent toggle
  line "on the line" wid 150%
~~~~

So, if there is just a single text label on a line, you probably
want to include either the "`above`" or "`below`" keyword.

~~~~ pikchr indent toggle
  line "above" above; move; line "`below`" below
~~~~

If there are two texts on the object, they straddle the center point
above and below, even without the use of the "`above`" and "`below`"
keywords:

~~~~ pikchr indent toggle
  line wid 300% "text without \"above\"" "text without \"below\""
~~~~

The "`above`" and "`below`" attributes do not stack or accumulate.  Each "`above`"
or "`below`" overrides any previous "`above`" or "`below`" for the same text.

If there are multiple texts and all are marked "`above`" or "`below`", then
all are placed above or below the center point, in order of appearance.

~~~~ pikchr indent toggle
  line width 200% "first above" above "second above" above
  move
  line same "first below" below "second below" below
~~~~

### Justify Text Left Or Right

As the "`above`" and "`below`" keywords control up and down positioning of
the text, so the "`ljust`" and "`rjust`" keywords control left and right
positioning.

For a line, the "`ljust`" means that the left side of the text is flush
against the center point of the line.  And "`rjust`" means that the right
side of the text is flush against the center point of the line.
(In the following diagram, the red dot is at the center of the line.)

~~~~ pikchr indent toggle
   line wid 200% "ljust" ljust above "rjust" rjust below
   dot color red at previous.c
~~~~

For a block object, "`ljust`" shifts the text to be left justified
against the left edge of the block (with a small margin) and
"`rjust`" puts the text against the right side of the object (with
the same margin).

~~~~ pikchr indent toggle
   box "ljust" ljust "longer line" ljust "even longer line" ljust fit
   move
   box "rjust" rjust "longer line" rjust "even longer line" rjust fit
~~~~

The behavior of "`ljust`" and "`rjust`" for block objects in Pikchr differs
from legacy PIC.
In PIC, text is always justified around the center point, as in lines.
But this means there is no easy way to left justify multiple lines of
text within a "box" or "file", and so the behavior was changed for
Pikchr.

Pikchr allows two texts to fill the same vertical slot if one is
"`ljust`" and the other is "`rjust`".

~~~~ pikchr indent toggle
  box wid 300% \
     "above-ljust" above ljust \
     "above-rjust" above rjust \
     "centered" center \
     "below-ljust" below ljust \
     "below-rjust" below rjust
~~~~

### Text Attribute "center"

The "`center`" attribute cancels all prior "`above`", "`below`", "`ljust`", and
"`rjust`" attributes for the current text.

### Bold And Italic Font Styles

The "`bold`" and "`italic`" attributes cause the text to use a bold or
an italic font.  Fonts can be both bold and italic at the same time.

~~~~ pikchr indent toggle
  box "bold" bold "italic" italic "bold-italic" bold italic fit
~~~~

### Aligned Text

The "`aligned`" attribute causes text associated with a straight line
to be rotated to align with that line.

~~~~ pikchr indent toggle
  arrow go 150% heading 30 "aligned" aligned above
  move to 1cm east of previous.end
  arrow go 150% heading 170 "aligned" aligned above
  move to 1cm east of previous.end
  arrow go 150% north "aligned" aligned above
~~~~

To display rotated text not associated with a line attach the
text to a line that is marked "`invisible`"

~~~~ pikchr indent toggle
  box ht 200% wid 50%
  line invis from previous.s to previous.n "rotated text" aligned
~~~~

Note that the direction of aligned text is the same as the direction of
the line itself.  So if you draw a line from right to left, the aligned
text will appear upside down:

~~~~ pikchr indent toggle
  circle "C1" fit
  circle "C0" at C1+(2.5cm,-0.3cm) fit
  arrow from C0 to C1 "aligned" aligned above chop
~~~~

If you need aligned text on an arrow that goes from right to left,
and you want the text to appear rightside up, then actually draw
the arrow from left to right and include the "**&lt;-**" attribute
so that the arrowhead is at the beginning rather than at the end.
For example:

~~~~ pikchr indent toggle
  circle "C1" fit
  circle "C0" at C1+(2.5cm,-0.3cm) fit
  arrow from C1 to C0 "aligned" aligned above <- chop
~~~~

### Adjusting The Font Size

The "`big`" and "`small`" attributes cause the text to be a little larger
or a little smaller, respectively.  Two "`big`" attributes cause the
text to be larger still, as do two "`small`" attributes.  But the text
size does not increase or decrease beyond two "`big`" or "`small`" keywords.

~~~~ pikchr indent toggle
  box "small small" small small "small" small \
    "(normal)" italic \
    "big" big "big big" big big ht 200%
~~~~

A "`big`" keyword cancels any prior "`small`" keywords on the same text,
and a "`small`" keyword cancels any prior "`big`" keywords.
