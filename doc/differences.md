# Differences Between Pikchr And Legacy-PIC

Pikchr is mostly compatible with legacy PIC in the sense that it will
run most of the example scripts contained in the
[original technical report on PIC by BWK][bwk] with little to no change.
Nevertheless, some features of legacy PIC have been omitted, and new
features have been added.  This article attempts to highlight the
important differences.

[bwk]: /uv/pic.pdf

Pikchr is implemented from scratch, without reference to the original
PIC code, and without even access to a working version of legacy PIC
with which to perform experiments.  The syntax implemented by Pikchr
is based solely on the descriptions in the [BWK tech report][bwk] which was
intended as a user manual, not a precise description of the language.
Consequently, some details of Pikchr may differ from PIC without our
even being aware of it.  This document tries to list the differences
that we know of.  But there are likely omissions.

## 1.0 New Object Types:

Pikchr supports serveral new object types that were unavailable
in PIC.

~~~ pikchr center
oval "oval"
move
cylinder "cylinder"
move
file "file"
move
dot "  dot" ljust
~~~

Additional object types may be added in subsequence versions of Pikchr.

## 2.0 Units Other Than Inches

PIC operated purely in inches.  Pikchr allows you to attach a
units designator on numeric literals so that distances can be easily
expressed in other units.  For example, you can write "`2.3cm`" to
mean 2.3 centimeters.  This is easier and more intuitive than writing (say)
"`2.3*2.54`.  Pikchr still does all of its calculations in inches,
internally.  The "cm" suffix is actually part of the numeric literal
so that "`2.3cm`" is really just an alternative spelling for "`5.842`".

Units supported by Pikchr include:

  *  `cm` &rarr; centimeters
  *  `in` &rarr; inches (the default)
  *  `mm` &rarr; millimeters
  *  `pc` &rarr; picas
  *  `pt` &rarr; points
  *  `px` &rarr; pixels

Because the units are part of the numeric literal,
the unit designator cannot be separated from the number by whitespace.
Units only apply to numeric literals, not to expressions.


## 3.0 New Uses For "`radius`":

A positive "`radius`" attribute on "`box`" items causes the box
to be displayed with rounded corners:

~~~ pikchr center
box rad 15px "box" "radius 15px"
~~~

Similarly a "`radius`" value on a "`line`" or "`arrow`" with
multiple segments rounds the corners:

~~~ pikchr center
arrow rad 10px go heading 30 then go 200% heading 175 \
  then go 150% west "arrow" below "radius 10px" below
~~~

## 4.0 The "`color`" and "`fill`" attributes

  *  Mention hexadecimal notation for RGB color values
  *  Mention the 140 HTML color names

## 5.0 The "`thickness`" attribute

  *  Mention the "thick" and "thin" attributes

## 6.0 Enhanced ability to control text alignment and display

  *  **bold**
  *  **italic**
  *  **big**
  *  **small**
  *  **aligned**
  *  **fit**

## 7.0 Change numeric property values by a percentage

## 8.0 The "`chop`" attribute works very differently

## 9.0 The "`same as` *object*" construct

## 10.0 New ways to discribe line paths

  *  **go** *distance* **heading** *compass-angle*
  *  **go** *distance* *compass-point*
  *  **go** *direction* **until even with** *place*
  *  **close**

## 11.0 New syntax to describe positions

  *  *distance* **above** *position*
  *  *distance* **left of** *position*
  *  *distance* **heading** *compass-angle* **from** *position*
  *  *nth* **vertex of** *line-object*



## 12.0 Other miscellaneous new features

### 12.1 New ways to identify prior objects

  * **previous**
  * **first**
  * Name objects by their string labels

### 12.2 Support for C and C++ style comments

### 12.3 Variable names can start with "`$`" or "`@`"

### 12.4 New assignment operators for variables

  *  +=
  *  -=
  *  *=
  *  /=

### 12.5 "`invisible`" can optionally be spelled out

### 12.6 Identify text objects with the keyword "`text`"

### 12.7 New variables

  *  margin
  *  leftmargin

## 13.0 Discontinued Features

Pikchr deliberately omits some features of legacy PIC for security
reasons.  Other features are omitted for lack of utility

### 13.1 Omit "`sh`" and "`copy`" statements.

The "`sh`" command provided the script the ability to run arbitrary
shell commands on the host computer.  Hence "`sh`" was just a built-in
[RCE vulnerability].  Having the ability to run arbitrary shell
commands was a great idea when you were building a phototypestting
system Bell Labs Version-III Unix running on a dedicated PDP/11 in
1982.  But it has no place in modern web-facing applications.  We
stay as far away from that stuff as we can.

[rce]: https://en.wikipedia.org/wiki/Arbitrary_code_execution

The "`copy`" command is similar.  It inserts the text of arbitrary
files on the host computer into the middle of the PIC-script.

### 13.2 Omit "`for`" and "`if`" statements.

Pikchr omits all support for branching and looping.  Each Pikchr
graphic object maps directly into a single graphic object in the
output.  This is a choice made to enhance the security and safety
of Pikchr (without branching or looping, there is less opportunity
for mischief) and to keep the language simple and accessible.

If you need machine-generated code, employ a separate script
language like Python or TCL to generate the Pikchr script for
you.  Then you can employ all the branching and looping you want.
We just don't want to build that into a language that is openly
accessible to random passers-by on the internet.

### 13.3 Omit macros



### 13.4 Omit the built-in "`sprintf()`" function

The sprintf() function has well-known security concerns, and we
do not want to make potential exploits accessible to attackers.
Futhermore, the sprintf() is of little to no utility in a Pikchr
script that lacks loops.  A secure version of sprintf() could be
added to Pikchr, but doing that would basically require recoding
a security sprintf() from from scratch.  It is safer and easier
to simply omit it.

### 13.5 Omit "`{...}`" subblocks

The "`[...]`" style subblocks are fully supported and they work
just as well.
