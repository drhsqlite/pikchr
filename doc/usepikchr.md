# How To Use Pikchr In Fossil Markdown and Fossil Wiki Markup

## Embedded Pikchr In Markdown

To include a Pikchr diagram in the middle of a Markdown document
in Fossil, simple place the Pikchr script in a [fenced code block][fcb]
that has a class of "pikchr".  Like this:

~~~~~
   ~~~ pikchr
   arrow; box "Hello!"; arrow
   ~~~
~~~~~

Or like this:

~~~~~
   ``` pikchr
   arrow; box "Hello!"; arrow
   ```
~~~~~

The result appears as follows:

``` pikchr
arrow; box "Hello!"; arrow
```

By default, the Pikchr-generated image appears left-justifed.  If you
would prefer that the picture be centered, put the keyword "center"
after class tag.  Thus:

~~~~~
   ``` pikchr center
   arrow; box "Hello" "again"; arrow <-
   ```
~~~~~

Results in the following:

``` pikchr center
arrow; box "Hello" "again"; arrow <-
```

[fcb]: https://spec.commonmark.org/0.29/#fenced-code-blocks

## Embedded Pikchr In Fossil Wiki

[Fossil][fossil] supports its own document markup format called
(uncreatively) "[Fossil Wiki][fossilwiki]".  Fossil Wiki is basically
just a safe subset of HTML with a few simple hyperlink, paragraph break, and
list formatting enhancements. Fossil Wiki supports something
similar to "fenced code blocks" in a special "`<verbatim>`" tag.
All content in between "`<verbatim>`" and the next
"`</verbatim>`", is displayed exactly as written.  Hence, just as
fenced code blocks are used to add Pikchr support to Markdown, so too
the "`<verbatim>`" mechanism is used to add Pikchr support to Fossil Wiki.

In Fossil Wiki, Pikchr source text can be enclosed within
"`<verbatim type="pikchr">`" or "`<verbatim type="pikchr center"`>
through the next "`</verbatim>`" tag.  Hence, code like this:

~~~~~
   <verbatim type="pikchr center">
   arrow; ellipse "Hi, Y'all"; arrow
   </verbatim>
~~~~~

Will result in a display like this:

~~~ pikchr center
arrow; ellipse "Hi, Y'all"; arrow
~~~

[fossil]: https://fossil-scm.org/home
[fossilwiki]: /wiki_rules
