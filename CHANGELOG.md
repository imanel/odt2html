# Changelog

## 0.2.0 / 2015-01-29

- Extracted version to external file - this was causing some problems with bundler
- Sort styles before output - slower, but more consistent across platforms
- Consistency fix for metatag in Ruby 1.9.2
- Support Rubyzip new interface

## 0.1.1 / 2011-03-03
- Allow to put output into variable instead of forcing it to write to stdout

## 0.1.0 / 2011-03-02
- Forked to Github
- Added code to handle <text:line_break>
- Changed behaviour of <p> and <br> generation
- Updated files to follow Github convention
- Renamed to ODT2HTML
- Refactored to modular structure
- Added tests

## 2007-01-18
- Made --out parameter optional; if you don't give the parameter, output goes to STDOUT; this lets you use the program as a filter

## 2006-01-15
- Add code to handle <text:a> and <text:bookmark-start>

## 2006-01-02
- Added LGPL to all the source files
- If an ODT document refers to a non-existent graphic, don't crash.

## 2006-01-01
- First alpha release version

