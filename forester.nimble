# Package
version = "0.1"
author = "Samantha Marshall"
description = "application for piping data into InfluxDB"
license = "BSD 3-Clause"

srcDir = "src/"

bin = @["forester"]

skipExt = @["nim"]

# Dependencies
requires "nim >= 0.14.0"
requires "influx"
