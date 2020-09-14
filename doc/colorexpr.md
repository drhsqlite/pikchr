# color-expr

Pikchr tracks colors as 24-bit RGB values.  Black is 0.  White is
16777215.  Other color values are in between these two extremes.

Pikchr knows the names of the 140 standard HTML color names.  If you
use one of those color names in an expression, Pikchr will substitute
the corresponding RGB value.  For example, if you write:

~~~~~
    circle "Hi" fill Bisque
~~~~~

That is the equivalent of writing:

~~~~~
    circle "Hi" fill 16770244
~~~~~

Because 16770244 is the 24-bit RGB value for "Bisque".

To put it another way, Pikchr treats the keyword "Bisque" as an
alternative spelling for the numeric literal 16770244.
