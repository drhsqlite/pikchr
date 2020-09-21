# position

A *position* is a point on the SVG canvas.  A *[place](./place.md)* is
a specific position associated with an object.  Every *place* is a *position*,
but not every *position* is a *place*.  This page is about *position*.

  *  *expr* **,** *expr*
  *  *place*
  *  *place* **+** *expr* **,** *expr*
  *  *place* **-** *expr* **,** *expr*
  *  *place* **+ (** *expr* **,** *expr* **)**
  *  *place* **- (** *expr* **,** *expr* **)**
  *  **(** *position* **,** *position* **)**
  *  **(** *position* **)**
  *  *fraction* **of the way between** *position* **and** *position*
  *  *fraction* **way between** *position* **and** *position*
  *  *fraction* **between** *position* **and** *position*
  *  *fraction* **<** *position* **,** *position* **>**
  *  *distance* *which-way-from* *position*
  *  **intersect** **(** *object* **,** *object* **)**

## Absolute versus Place-relative Positions

One form of a position is an (X,Y) coordinate pair.  This works, but
its use is discouraged.  It is better to use positions that are 
either a *[place](./place.md)* or are derived from one or more places.

## The "**(** *position* **,** *position* **)**" Form

A place of the form "(pos1,pos2)" where pos1 and pos2 are other positions
means use the X coordinate from pos1 and the Y coordinate from pos2.

~~~ pikchr
leftmargin = 1cm;
P1: dot; text "P1" with .s at 2mm above P1
P2: dot at P1+(2cm,-2cm); text "P2" with .s at 2mm above P2
dot at (P1,P2); text "(P1,P2)" with .s at 2mm above last dot
dot at (P2,P1); text "(P2,P1)" with .s at 2mm above last dot
~~~

## "*fraction* **of the way between**" Forms

All of these syntactic forms of position are the same:

  *  *fraction* **of the way between** *position* **and** *position*
  *  *fraction* **way between** *position* **and** *position*
  *  *fraction* **between** *position* **and** *position*
  *  *fraction* **<** *position* **,** *position* **>**

The last form is the most cryptic, but it is also the most compact
and hence ends up being the most often used.

In all cases *fraction* is an expression that usually evaluates to between 0.0
and 1.0.  The resulting position is that fraction along a line that
connects the first *position* to the second *position*.

The *fraction* can be less than 0.0 or greater than 1.0, in which case
the point is on the extended line that connects the two positions.

~~~ pikchr
P1: dot; text "P1" with .s at 2mm above P1
P2: dot at P1+(4cm,1.5cm); text "P2" with .s at 2mm above P2
line thin color gray dotted from -.5<P1,P2> to 1.5<P1,P2>
dot at 3/4<P1,P2>; text "3/4<P1,P2>" at (last dot,P1)
   arrow thin color gray from last text.n to 1mm south of last dot
dot at -0.25 of the way between P1 and P2
   text "-0.25 of the way between P1 and P2" at (last dot,P2)
   arrow thin color gray from last text.s to 1mm north of last dot
~~~

## "*position* *which-way-from* *position*" Forms

It is very common to specify a position as an offset from some other
position using this format.  Some examples:

  *  1cm below Obstacle.s
  *  0.5*linewid left of C0.w
  *  dist(C2,C3) heading 30 from C2

## The "**intersect** **(** *object* **,** *object* **)**" Form

This form returns the position where the two line objects intersect.
It cannot be used with non-line classes.

The "line"s going into the calculation are taken from the "`.start`"
and "`.end`" points of the objects.
For straight lines this coincides with the visible line.
This is not true anymore when the line has more than one path segment.

~~~ pikchr
# triangulation
A: arrow from (0,0)    to (1,-0.2) "Reading 1" aligned above
B: arrow from (-0.5,2) to (1,0.3)  "Reading 2" aligned below
line dashed from A.end to 2   between A.start and A.end
line dashed from B.end to 1.5 between B.start and B.end
circle color red at intersect(A,B) thick rad 0.1
text with .w at previous.ne "The treasure is here"
~~~

The function will throw errors when

  - Invoked with non-line objects
  - The two lines are parallel, i.e. do not intersect.
  - The two lines coincide, i.e. the set of intersections is infinite.
