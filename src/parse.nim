# =======
# Imports
# =======

import os
import re
import tables
import lexbase
import logging
import streams
import strutils

import "formatter.nim"
import "command.nim"

# =====
# Types
# =====

type
  LogLexer* = object of BaseLexer
    format*: FormatType

  Offset* = object
    pos*: int
    len*: int

# =========
# Constants
# =========

const
  NewLinesAndEoF = lexbase.NewLines + {lexbase.EndOfFile}

# =========
# Templates
# =========

## alias for both properties that indicate position in the Lexer's buffer
template getPosition*(p: LogLexer): int =
  p.offsetBase + p.bufpos

# =========
# Functions
# =========

## Used to update the existing offsets of the parser.
##   at end of a line or relevant section, the parser should
##   be updated to account of everything read up until now
##   as the `offsetBase` property instead of the `bufpos`
##   property.
proc updateOffset*(p: ptr LogLexer) =
  p.offsetBase += p.bufpos
  p.bufpos = 0

##
proc read(p: LogLexer, size: uint): seq[char] =
  var counter: uint = 0
  var data = newSeq[char]()
  var pos = p.getPosition()
  while counter < size:
    data.add(p.buf[pos])
    inc(pos)
    inc(counter)
  return data

##
proc findNext(p: LogLexer, chr: char): int =
  var pos = p.getPosition()
  let original_position = pos
  var curr = p.buf[pos]
  while curr != chr:
    inc(pos)
    curr = p.buf[pos]
  return (pos - original_position)

## Peek the contents of the next line.
##   First will read up until encountering a newline character
##   or EoF, which-ever comes first. If it is EoF, then return
##   with the lenth remaining until then and an empty string
##   (as there was no next line to peek). Otherwise, return the
##   length from the current position to start of the next line,
##   as well as the contents of the next line as a string.
proc peekLine*(p: LogLexer): (Offset, string) =
  var pos = p.getPosition()
  var original_position = pos
  var line_end = p.findNext('\n')
  if line_end >= p.bufLen:
    error("hit end of file before hitting a new line!")
    return (Offset(pos: pos - original_position, len: line_end - pos), "")
  while not (p.buf[line_end] in NewLinesAndEoF):
    inc(line_end)
    #debug(p.buf[line_end])
  return (
    Offset(pos: pos - original_position, len: line_end - pos),
    ($p.buf)[pos..line_end])

##
proc peekCurLine*(p: LogLexer): (Offset, string) =
  var pos: int = p.getPosition()
  let original_position = pos
  while (pos >= 0) and not (p.buf[pos] in NewLinesAndEoF):
    dec(pos)
    #debug("stepping back: " & p.buf[pos])
  inc(pos)
  var line_end = pos
  if line_end >= p.bufLen:
    error("hit end of file before hitting a new line!")
    return (Offset(pos: pos - original_position, len: line_end - pos), "")
  while not (p.buf[line_end] in NewLinesAndEoF):
    inc(line_end)
    #debug(($p.buf[line_end]).toHex())
  let offset = Offset(pos: pos - original_position, len: line_end - pos)
  if offset.len == 0:
    return (offset, "")
  return (offset, ($p.buf)[pos..line_end])

## Peek at the contents of the next character in the buffer.
##   return the next character or EoF, if we are venturing
##   beyond the end of the buffer.
proc peekChar*(p: LogLexer): char =
  var pos: int = p.getPosition()
  inc(pos)
  #debug(p.buf[pos])
  if pos < p.bufLen:
    return p.buf[pos]
  return lexbase.EndOfFile

## Checks if the current line is indented
##  assumes that the lexer is at the start of the line, and are
##  4 space character indents.
proc isLineIndented*(p: LogLexer): bool =
  var pos: int = p.getPosition()
  while p.buf[pos] == ' ':
    inc(pos)
    debug("found a space!")
  let length = pos - p.getPosition()
  #debug(length)
  return (length == 4)

## Reads up to the end of the word.
##  assumes that current lexer position is the start of the word.
##  also assumes that spaces are the end of a word unless preceded
##  by a backslash escape.
proc readWord*(p: LogLexer): int =
  var pos: int = p.getPosition()
  var prev: char = ' '
  #[
    keep advancing the parser while not encountering spaces,
    but allowing to keep grabbing input if there is an escaped
    space.
  ]#
  while (not (p.buf[pos] in {' ', '\n'})) or (prev in {'\\'}):
    prev = char(p.buf[pos])
    inc(pos)
    debug($prev & " -> " & $p.buf[pos])
  dec(pos)
  return pos

##
proc resetToStartOfLine(p: LogLexer): int =
  var pos = p.getPosition()
  var prev: char = ' '
  while p.buf[pos] != '\n':
    dec(pos)
  inc(pos)
  return pos

## Pretty-Parse the contents of the given stream
proc prettyParse*(input: Stream, fileLength: int,
  format: FormatType): (bool, string) =

  var success = false
  var data = newSeq[string]()
  var p = LogLexer(format: format)
  try:
    p.open(input, fileLength)
    # begin
    # p.bufpos = 650491
    # updateOffset(addr p)

    var lines_count = 0
    var matched_lines = 0

    while p.getPosition() < p.bufLen and
      p.buf[p.getPosition()] != lexbase.EndOfFile:

      info("at position " & $p.getPosition() & " of " & $p.bufLen)
      #[
      if p.isLineIndented():
        warn("current line is indented...")
        let (next, line) = p.peekLine()
        warn("from " & $p.getPosition())
        p.bufpos = next.len
        updateOffset(addr p)
        warn("to " & $p.getPosition())
        inc(lines_count)
        inc(child_lines)
        data.add(line)
        continue
      ]#
      let (offset, peek_line) = p.peekCurLine()
      debug(peek_line)
      var matches: array[re.MaxSubpatterns, string]
      var matched_pattern = false
      for pattern in command.collection:
        if not matched_pattern:
          matched_pattern = peek_line.match(re(pattern), matches)
          if matched_pattern:
            inc(matched_lines)
            debug(matches)
      p.bufpos = offset.len + 1
      updateOffset(addr p)
      inc(lines_count)
      data.add(peek_line)

    error("counted " & $lines_count & " lines...")
    error("matched " & $matched_lines & " lines...")
    success = (matched_lines == lines_count)

    # end
  finally:
    p.close()
  return (success, data.join("\n"))

proc prettyParse*(input: Stream, format: FormatType): (bool, string) =
  return prettyParse(input, 100000000, format)
