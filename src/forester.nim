# =======
# Imports
# =======

import os
import parseopt2

# =========
# Functions
# =========

proc progName(): string =
  result = getAppFilename().extractFilename()

proc usage(): void = 
  echo("usage: " & progName() & " [-v|--version] [-h|--help]")
  echo("\n")
  echo( progName() & " is meant to be run as a system daemon, please ") 
  quit(QuitSuccess)

proc versionInfo(): void =
  echo(progname() & " v0.1")
  quit(QuitSuccess)

# ===========================================
# this is the entry-point, there is no main()
# ===========================================

for kind, key, value in getopt():
  case kind
  of cmdLongOption, cmdShortOption:
    case key
    of "help", "h":
      usage()
    of "version", "v":
      versionInfo()
    else:
      discard
  else:
    discard

if not existsEnv("FORESTER_CONFIG_DIR"):
  echo("Please define `FORESTER_CONFIG_DIR` in the running environment to point to the specified configuration directory")
  quit(QuitFailure)

