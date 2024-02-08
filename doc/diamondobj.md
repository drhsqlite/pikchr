# Diamond objects

A diamond acts much like a [box](./boxobj.md) except that its corners
are rotated around the center point such that they become the shape’s
four primary cardinal points:

~~~~ pikchr indent
D: diamond "Cardinal" "Points"
   dot ".n" above at D.n
   dot " .e" ljust at D.e
   dot ".s" below at D.s
   dot ".w " rjust at D.w
~~~~

Indeed, before Pikchr [got this primitive](/info/36751abee2), the
workaround was to draw an invisible box to hold the text, then draw
lines between its cardinal points:

~~~~ pikchr indent
box width 150% invis "“Diamond”" "Label"
line from last.w to last.n to last.e to last.s close
~~~~

This does work, and it has the advantage of being compatible with the
original PIC and with GNU `dpic`, but it also has a number of
weaknesses, one of which is evident in comparing the examples above: the
labels aren’t as well-centered when manually drawing the diamond between
the invisible bounding box’s cardinal points.

Another is the need for that 150% fudge factor to the invisible box’s
width, without which the labels would be truncated by the dimensions
Pikchr calculates for the invisible bounding box:

~~~~ pikchr indent
box invis "“Diamond”" "Label"
line from last.w to last.n to last.e to last.s close
~~~~

There’s a third, more subtle advantage to having this primtive built
into the language: the location of the ordinal points is now
well-defined:

~~~~ pikchr indent
D: diamond "Ordinal" "Points"
   dot " .ne" ljust above at D.ne
   dot " .se" ljust below at D.se
   dot ".sw " rjust below at D.sw
   dot ".nw " rjust above at D.nw
~~~~

To replicate that with the PIC-compatible hack above, you’d have to do
the geometry to work out where those points land along the lines. It’s
better to leave that bit of tedious math to the Pikchr renderer.

Unlike a box, you cannot currently round the corners on a diamond. You
can, however, programmatically override the default height and width
by redefining the `diamondht` and `diamondwid` variables. Here we show
two different ways of making the diamond 25% larger:

~~~~ pikchr indent
D:  diamond thick "Diamond" "Dimensions" width 125% height 125%

X1: line thin color gray left 70% from 4mm left of (D.w,D.n)
X2: line same from 4mm left of (D.w,D.s)
    text "height" small at 1/2 way between X1 and X2
    line thin color gray from previous text.n up   until even with X1 ->
    line thin color gray from previous text.s down until even with X2 ->
X3: line thin color gray down 50% from 2mm below (D.w,D.s)
X4: line same from 2mm below (D.e,D.s)
    text "width" small at 1/2 way between X3 and X4
    line thin color gray from previous text.w left  until even with X3 ->
    line thin color gray from previous text.e right until even with X4 ->

    diamondht  = diamondht  * 1.25
    diamondwid = diamondwid * 1.25
    diamond thick "Diamond" "Dimensions" at 1.5in right of D
~~~~
