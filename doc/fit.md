# The `fit` attribute

The "`fit`" attribute causes an object to automatically adjust its
"`width`", "`height`", and/or "`radius`" so that it will enclose its
text annotations with a reasonable margin.

The "`fit`" attribute only works with text annotations that occur
earlier in the object definition.  In other words, the "`fit`" keyword
should come after all text annotations have been defined.

## Pikchr has to guess at the size of text

Pikchr does not have access to the SVG rendering engine.  Therefore,
it cannot know the precise dimensions of text annotations.  It has to
guess.  Usually Pikchr does a reasonable job, but sometimes it can be
a little off, especially with unusual characters.  If "`fit`" causes the
object to be too narrow, you can try adding spaces at the beginning and
end of the longest text annotation.  You can also adjust the width
and height by a percentage after running "`fit`":

   *  `width 110%`
   *  `height 90%`
   *  `radius 120%`

And so forth.  Substitute percentage increases and decreases, as
appropriate, to make the text fit like you want.
