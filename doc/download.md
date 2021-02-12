# Download Options

## The `pikchr.c` source file.

The latest trunk version of the C source file for Pikchr is always
available from the following link:

  *  <https://pikchr.org/home/file/pikchr.c?ci=trunk>

This is everything you need if you just want to build the Pikchr
command-line tool, or use the Pikchr library in another application.
Compile this file using commands like these:

  *  `gcc -c pikchr.c`  &larr; to build the Pikchr library

  *  `gcc -DPIKCHR_SHELL -o pikchr pikchr.c -lm` &larr; to build the
     pikchr command-line tool

See the [How To Compile Pikchr](./build.md) and the
[How To Integrate Pikchr Into New Systems](./integrate.md) documents
for more details on how to compile Pikchr.

## Complete Source Tree Tarball

A tarball or ZIP archive of the latest source code is available
at the following links:

  *  <https://pikchr.org/home/tarball/trunk/pikchr.tar.gz>
  *  <https://pikchr.org/home/zip/trunk/pikchr.zip>

With the complete source tree on your local machine, you can run
"`make test`" to build and test Pikchr.

## Clone The Fossil Repository

Pikchr uses [Fossil](https://fossil-scm.org/home) for version control.
You can clone the entire repository (which includes everything on
this website, including all the documentation and test cases) as follows:

  *  [Install Fossil](https://fossil-scm.org/home/uv/download.html)
      if you haven't done so already

  *  `fossil clone https://pikchr.org/ pikchr.fossil`

  *  `fossil open pikchr.fossil`

After you have the repository cloned, you can bring in any updates using:

  *  `fossil up trunk`

Once you have a clone of the Fossil repository, you can bring up a
copy of this website on your local machine by typing:

  *  `fossil ui`

See the [Fossil documentation][fossil-doc] for more information on how
manage a Fossil repository.

[fossil-doc]: https://fossil-scm.org/home/doc/trunk/www/permutedindex.html

## Clone The GitHub Mirror

There is a (read-only) mirror of this repository on GitHub

  *  <https://github.com/drhsqlite/pikchr>
