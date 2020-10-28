# Arrowheads

Line objects ("line", "arrow", "spline", and "arc") can have one
of the following attributes to specify which ends of the line contain
arrowheads:

  *  **-&gt;**
  *  **&lt;-**
  *  **&lt;-&gt;**

The first form (**-&gt;**) means that there is an arrowhead at the end.
This is the default for "arrow".  The second form (**&lt;-**) means that
there is an arrowhead at the beginning only.  The third form means that
there are arrowheads at both ends.

Note that "`arrow`" and "`line ->`" look identical to one another.

If there are multiple occurrences of these attributes on a single object,
then the last one is the one that matters.
