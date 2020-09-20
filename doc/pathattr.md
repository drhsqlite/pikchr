# path-attribute

A *path-attribute* is used provide the origin and direction of a line
object (arc, arrow, line, move, or spline).  It is an error to use a
*path-attribute* on
a block object (box, circle, cylinder, dot, ellipse, file, oval, or text).

There are seven forms:

  *  **from** *position*
  *  **then**? **to** *position*
  *  **then**? **go**? *direction* *distance*?
  *  **then**? **go**? *direction* **until**? **even with** *place*
  *  (**then**|**go**) *distance*? **heading** *compass-angle*
  *  (**then**|**go**) *distance*? *compass-direction*
  *  **close**

The "`from`" attribute is used to assign the the starting location
of the line object (its ".start" value).  The other six forms
(collectively called "to" forms) assign
intermediate vertexes or the end point (.end).   If the "`from`"
is omitted, then "`from previous.end`" is assumed, or if there
is no previous object, "`from (0,0)`".   If no "to" forms are
provided then a single movement in the current layout direction
by either the "linewid" or "lineht" (depending on layout direction)
is used.

The "from" can occur
either before or after the various "to" subclauses.  That does not
matter.  But the order of the various "to" subclauses do matter, of course.

If there are two consecutive *direction* clauses (*direction* is
always one of "`right`", "`down`", "`left`", or "`right`") then
the two will be combined to specify a single line segment.
Hence, the following are equivalent:


  *  ... **right 4cm up 3cm** ...
  *  ... **go 5cm heading 53.13010235** ...

~~~ pikchr
leftmargin = 1cm
A1: arrow thick right 4cm up 3cm
dot at A1.start
X1: line thin color gray from (0,-3mm) down 0.4cm
X2: line same from (4cm,-3mm) down 0.4cm
arrow thin color gray from X1 to X2 "4cm" above
X3: line same from (4cm+3mm,0) right 0.4cm
X4: line same from (4cm+3mm,3cm) right .4cm
arrow thin color gray from X3 to X4 "3cm" aligned above
X5: line same from A1.start go 4mm heading 90+53.13010235
X6: line same from A1.end go 4mm heading 90+53.13010235
arrow thin color gray from X5 to X6 "5cm" below aligned
line same from (0,1cm) up 1cm
spline -> from 1.5cm heading 0 from A1.start \
   to 1.5cm heading 10 from A1.start \
   to 1.5cm heading 20 from A1.start \
   to 1.5cm heading 30 from A1.start \
   to 1.5cm heading 40 from A1.start \
   to 1.5cm heading 53.13 from A1.start \
   thin color gray "53.13&deg;" aligned center small
~~~

If two separate movements are desired, one 4cm right and another 3cm up,
then "right" and "up" subphrases must be separated by the "`then`" keyword:

  *  ... **right 4cm then up 3cm** ...

~~~ pikchr
leftmargin = 1cm
A1: arrow thick right 4cm then up 3cm
dot at A1.start
X1: line thin color gray from (0,-3mm) down 0.4cm
X2: line same from (4cm,-3mm) down 0.4cm
arrow thin color gray from X1 to X2 "4cm" above
X3: line same from (4cm+3mm,0) right 0.4cm
X4: line same from (4cm+3mm,3cm) right .4cm
arrow thin color gray from X3 to X4 "3cm" aligned above
~~~

## The "`until even with`" subclause

*TBD*

## The "`close`" subclause

*TBD*
