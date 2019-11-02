import parsecfg
import osproc
import streams
import os
import system
import strformat
import sequtils, sugar

type SaxonArgs = tuple[xsltPath: string, args: seq[string]]

proc requireValue(c: Config, section, key: string): string =
  let v = c.getSectionValue(section, key)

  if v == "":
    var e: ref IOError
    e.new()
    e.msg = &"No config value found for {section} / {key}"
    raise e
  else:
    return v

# For now this means we get the first arg as the XSLT file, and the rest
# as args to pass through to Saxon
proc sliceArgv(): SaxonArgs =
  let argv = commandLineParams()
  let xslt: string = argv[0].string
  let rest: seq[string] = argv[1..<argv.len].map( x => x.string )
  return (
    xsltPath: xslt,
    args: rest
  )

let config_file = joinPath(getConfigDir(), "seax/config.ini")
var config: Config

try:
  config = loadConfig(config_file)
except IOError:
  echo "Failed to read config file!"
  quit(1)

let saxon_jar = config.requireValue("saxon", "jar_path")
let saxon_config = config.requireValue("saxon", "config")

if not fileExists(saxon_jar):
  echo "Cannot find Saxon JAR file at " & saxon_jar

let saxonArgs = sliceArgv()

let p = startProcess(
  "java",
  args=(@["-cp", saxon_jar, "net.sf.saxon.Transform", "-config:" & saxon_config,  "-xsl:" & saxonArgs.xsltPath, "-it:main"] & saxonArgs.args),
  options={poUsePath, poStdErrtoStdOut}
)

#let p = startProcess(
  #"java",
  #args=(@["-cp", saxon_jar, "net.sf.saxon.Query", "-config:" & saxon_config] & saxonArgs.args),
  #options={poUsePath, poStdErrtoStdOut}
#)

discard p.waitForExit()

echo p.outputStream().readAll()
