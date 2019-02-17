# =======
# Imports
# =======

import os
import logging
import rdstdin
import streams
import parseopt
import strutils
import terminal

import "formatter.nim"
import "parse.nim"

# =====
# Types
# =====

type
  LoggingLevel {.pure.} = enum
    Debug = lvlAll,
    Verbose = lvlNotice,
    None = lvlError

# =========
# Functions
# =========

proc progName(): string =
  result = getAppFilename().extractFilename()

proc usage(): void =
  echo("usage: " & progName() & "\n" &
      "\t-v,--version                      # prints version number\n" &
      "\t-h,--help                         # displays usage info\n" &
      "\t--verbose,--debug                 # displays verbose logging info\n" &
      "\t-f,--format=plain|html|html-full  # output format\n" &
      "\t--save-as='file name.log'         # if the raw log should be saved")
  quit(QuitSuccess)

proc versionInfo(): void =
  echo(progname() & " v0.1.0")
  quit(QuitSuccess)

# ===========================================
# this is the entry-point, there is no main()
# ===========================================

var enabled_save_file = false
var save_input = ""

var formatter_option = FormatType.None

var log_files = newSeq[string]()

var logging_level = lvlError

var parser = initOptParser()

for kind, key, value in parser.getopt():
  case kind
  of cmdLongOption, cmdShortOption:
    case key
    of "help", "h":
      usage()
    of "version", "v":
      versionInfo()
    of "verbose":
      logging_level = lvlNotice
    of "debug":
      logging_level = lvlAll
    of "format", "f":
      case value
      of "plain":
        formatter_option = FormatType.Plain
      of "html":
        formatter_option = FormatType.Html
      of "html-full":
        formatter_option = FormatType.HtmlFull
    of "save-as":
      enabled_save_file = true
      save_input = value
    else:
      discard
  of cmdArgument:
    log_files.add(key)
  else:
    discard

var logger = newConsoleLogger(logging_level)
addHandler(logger)

var contents: Stream

if log_files.len() == 0:
  debug("no file  arguments, checking stdin...")
  if not isatty(stdin):
    debug("reading contents of stdin...")
    contents = newFileStream(stdin)
    let (output, data) = prettyParse(contents, formatter_option)
    if not output:
      error("unable to parse log file")
    if enabled_save_file:
      let writer = openFileStream(save_input, fmWrite, len(data))
      writer.write(data)
      writer.close()
else:
  debug("iterating over passed log files...")
  for file in log_files:
    debug("selected file: " & file & " ...")
    let filename = file.extractFilename()
    let stream = newFileStream(file.expandFilename())
    debug("accessing stream of file...")
    let size = int(file.getFileSize())
    let (output, data) = prettyParse(stream, size, formatter_option)
    if not output:
      error("unable to parse contents of \"" & file & "\"")
    if enabled_save_file:
      let writer = openFileStream((filename & "+" & save_input), fmWrite,
          size)
      writer.write(data)
      writer.close()
