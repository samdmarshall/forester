# =======
# Imports
# =======

import re
import macros
import tables
import strutils

# =====
# Types
# =====

type
  Section* = object
    name*: string
    details*: Table[string, string]
    commands: seq[Command]

  Command* = object
    name*: string
    line: string
    children: seq[string]

# =========
# Constants
# =========

## This is to create a new `const` value that collects all
## the pattern expressions below and make an iterable list
macro collect(x: untyped): untyped =

  var collection = newNimNode(nnkConstDef)
  let ident = newIdentNode("collection")
  let postfix = ident.postfix("*")
  collection = add(collection, postfix)
  collection = add(collection, newEmptyNode())
  var value = newNimNode(nnkBracket)

  for item in x[0].items():
    for property in item.children():
      if property.kind == nnkPostfix:
        let (node, info) = property.unpackPostfix()
        value.add(newIdentNode($node))

  let prefix = value.prefix("@")
  collection = collection.add(prefix)
  let collected_values = add(x[0], collection)

  return collected_values

collect:
  const
    analyze* = r"(Analyze(?:Shallow)?) (.*\/(.*\.(?:m|mm|cc|cpp|c|cxx))) .*\(in target: (.*)\)"
    checkDependencies* = r"(Check dependencies)"
    envStatement* = r" {4}(.*)(=)(.*)$"
    shellCommand* = r" {4}(cd|setenv|(?:[\w\/:\\ \-.]+?\/)?[\w\-]+) (.*)$"
    cleanRemove* = r"Clean.Remove"
    targetAction* = r"=== (.*) TARGET (.*) OF PROJECT (.*) WITH CONFIGURATION (.*) ==="
    codesign* = r"(CodeSign) ((?:\\ |[^ ])*)$"
    codesignFramework* = r"(CodeSign) ((?:\\ |[^ ])*.framework)\/Versions"
    compile* = r"(Compile)[\w]+ .+? ((?:\\.|[^ ])+\/((?:\\.|[^ ])+\.(?:m|mm|c|cc|cpp|cxx|swift))) .*\(in target: (.*)\)"
    compileCommand* = r" *(.*clang .* \-c (.*\.(?:m|mm|c|cc|cpp|cxx)) .*\.o)$"
    compileXib* = r"(CompileXIB) (.*\/(.*\.xib)) .*\(in target: (.*)\)"
    compileStoryboard* = r"(CompileStoryboard) (.*\/([^\/].*\.storyboard)) .*\(in target: (.*)\)"
    copyHeader* = r"(CpHeader) (.*\.h) (.*\.h) \(in target: (.*)\)"
    copyPlist* = r"(CopyPlistFile) (.*\.plist) (.*\.plist) \(in target: (.*)\)"
    copyStrings* = r"(CopyStringsFile) (.*\.strings) (.*\.strings) \(in target: (.*)\)"
    cpresource* = r"(CpResource) (.*) \/(.*) \(in target: (.*)\)"
    executed* = r" *Executed (\d+) test[s]?, with (\d+) failure[s]? \((\d+) unexpected\) in \d+\.\d{3} \((\d+\.\d{3})\) seconds"
    failingTest* = r" *(.+:\d+): error: [\+\-]\[(.*) (.*)\] :(?: '.*' \[FAILED\],)? (.*)"
    uiFailingTest* = r" {4}t =  +\d+\.\d+s +Assertion Failure: (.*:\d+): (.*)$"
    restartingTests* = r"Restarting after unexpected exit or crash in.+$"
    mkDir* = r"(MkDir) (.*\/(.+))( \(in target: (.*)\))"
    generateDsym* = r"(GenerateDSYMFile) \/.*\/(.*\.dSYM) \/.* \(in target: (.*)\)"
    libtool* = r"(Libtool) .*\/(.*) .* .* \(in target: (.*)\)"
    linking* = r"(Ld) \/?.*\/(.*?) normal .* \(in target: (.*)\)"
    testCasePassed* = r"Test [C|c]ase '(-\[(.*) (.*)\]|(.*))' (?:passed on|passed)? \'(xctest \(\d*\))?\' \((\d*\.\d{3}) seconds\)(?:\.)?"
    testCaseStarted* = r"Test '(-\[)?(.*) (.*)(\])?' started.$"
    testCasePending* = r"Test Case '(-\[)?(.*) (.*)PENDING(\])?' passed"
    testCaseMeasured* = r"[^:]*:[^:]*: Test Case '(-\[)?(.*) (.*)(\])?' measured \[Time, seconds\] average: (\d*\.\d{3})(.*){4}"
    parallelTestCasePassed* = r"Test '(.*)\.(.*)\(\)' passed on '(.*) - (.*)' \((\d*\.(.*){3}) seconds\)"
    parallelTestCaseAppKitPassed* = r" *Test case '(-\[)?(.*) (.*)(\])?' passed on '.*' \((\d*\.\d{3}) seconds\)"
    parallelTestCaseFailed* = r"Test '(.*)\.(.*)\(\)' failed on '(.*) - (.*)' \((\d*\.(.*){3}) seconds\)"
    parallelTestingStarted* = r"Testing started on '(.*)'"
    phaseSuccess* = r"\*\* (.*) SUCCEEDED \*\*"
    phaseScriptExecution* = r"(PhaseScriptExecution) (.*) \/.*\.sh \(in target: (.*)\)"
    processPch* = r"(ProcessPCH) .* \/.*\/(.*.pch) normal .* .* .* \(in target: (.*)\)"
    processPchCommand* = r" *.*\/usr\/bin\/clang .* \-c (.*) \-o .*"
    preprocess* = r"(Preprocess) (?:(?:\\ |[^ ])*) ((?:\\ |[^ ])*)$"
    pbxcp* = r"(PBXCp) (.*) \/(.*) \(in target: (.*)\)"
    processInfoPlist* = r"(ProcessInfoPlistFile) .*\.plist (.*\/+(.*\.plist))( \(in target: (.*)\))?"
    testsRunCompletion* = r" *Test Suite '(?:.*\/)?(.*[ox]ctest.*)' (finished|passed|failed) at (.*)"
    testSuiteStarted* = r" *Test Suite '(?:.*\/)?(.*[ox]ctest.*)' started at(.*)"
    testSuiteStart* = r" *Test Suite '(.*)' started at"
    tiffutil* = r"(TiffUtil) (.*)"
    touch* = r"(Touch) (.*\/(.+)) \(in target: (.*)\)"
    writeFile* = r"(write-file) (.*)"
    writeAuxiliaryFiles* = r"(Write auxiliary files) (.*)"
    compileWarning* = r"((\/.+\/(.*):.*:.*): (warning)): (.*)$"
    ldWarning* = r"((ld): (warning)): (.*)"
    genericWarning* = r"(warning): (.*)$"
    willNotBeCodeSigned* = r"(.* will not be code signed because .*)$"
    clangError* = r"(clang: error:.*)$"
    checkDependenciesErrors* = r"(Code ?Sign error:.*|Code signing is required for product type .* in SDK .*|No profile matching .* found:.*|Provisioning profile .* doesn't .*|Swift is unavailable on .*|.?Use Legacy Swift Language Version.*)$"
    provisioningProfileRequired* = r"(.*requires a provisioning profile.*)$"
    noCertificate* = r"(No certificate matching.*)$"
    compileError* = r"(\/.+\/(.*):.*:.*): (?:fatal )?error: (.*)$"
    cursor* = r"([ ~]*\^[ ~]*)$"
    fatalError* = r"(fatal error:.*)$"
    fileMissingError* = r"<unknown>:0: (error: .*) '(\/.+\/.*\..*)'$"
    ldError* = r"(ld):(.*)"
    linkerDuplicateSymbolsLocation* = r" +(\/.*\.o[\)]?)$"
    linkerDuplicateSymbols* = r"(duplicate symbol .*):$"
    linkerUndefinedSymbolLocation* = r"(.* in .*\.o)$"
    linkerUndefinedSymbols* = r"(Undefined symbols for architecture .*):$"
    podsError* = r"(error): (.*)"
    symbolReferencedFrom* = r" +\Q(.*)\E, referenced from:$"
    moduleIncludesError* = r"\<module-includes\>:.*?:.*?: (?:fatal )?(error: .*)$/"
    userDefaultsFromCommandLine* = r"(User defaults from command line):$"
    note* = r"(note): (.*)"
    createBuildDirectory* = r"(CreateBuildDirectory) (.*) \(in target: (.*)\)"
    analyzerMarker* = r"\s*\^$"
    generatingCoverageData* = r"(Generating coverage data...)"
    generatedCoverageReport* = r"(Generated coverage report): (.*)"

