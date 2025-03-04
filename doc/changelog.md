# Release History

## Version 1.1 (2024-03-04)

  *  Adjust the `<svg>` markup slightly to work around an issue in Safari.
  *  Fix a bug in the "with EDGE at POSITION" syntax reported in
     [forum post f9f5d90f33](/forumpost/f9f5d90f33).
  *  Add the --version argument to the "pikchr" command-line tool.
  *  Add the `pikchr_version()` API function that returns a string showing
     the Pikchr version number and the date/time of the source code check-in.
  *  Include the ISO timestamp of the source code check-in in a data-*
     field of the `<svg>` element.

## Version 1.0 (2024-04-01)

  *  Add a version number (1.0 in this case) because
     Homebrew requires all the software they deliver to
     have a version number, and we want Pikchr to be
     available via Homebrew.
