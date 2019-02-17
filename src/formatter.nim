# =======
# Imports
# =======

import htmlgen
import streams
import parsexml
import strutils
import strformat

import "command.nim"

# =====
# Types
# =====

type
  FormatType* = enum
    None,
    Plain,
    Html,
    HtmlFull

# =========
# Functions
# =========

proc writeOutput*(input: string, format: FormatType) =
  let output = newFileStream(stdout)
  case format
  of Plain:
    output.write(input)
  of Html:
    discard
  of HtmlFull:
    discard
  else:
    discard
