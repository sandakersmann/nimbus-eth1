# Nimbus
# Copyright (c) 2018-2019 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

## Pretty printing, an alternative to `$` for debugging
## ----------------------------------------------------
##
## minimal dependencies, avoiding circular import

import
  std/[sequtils, strformat, strutils, tables, times],
  nimcrypto/hash

export
  sequtils, strformat, strutils

const
  ZeroHash256 =    MDigest[256].default

  EmptyUncleHash = ( "1dcc4de8dec75d7aab85b567b6ccd41a" &
                     "d312451b948a7413f0a142fd40d49347" ).toDigest

  BlankRootHash =  ( "56e81f171bcc55a6ff8345e692c0f86e" &
                     "5b48e01b996cadc001622fb5e363b421" ).toDigest

  EmptySha3 =      ( "c5d2460186f7233c927e7db2dcc703c0" &
                     "e500b653ca82273b7bfad8045d85a470" ).toDigest

  EmptyRlpHash =   ( "56e81f171bcc55a6ff8345e692c0f86e" &
                     "5b48e01b996cadc001622fb5e363b421" ).toDigest

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

proc reGroup(q: openArray[int]; itemsPerSegment = 16): seq[seq[int]] =
  var top = 0
  while top < q.len:
    let w = top
    top = min(w + itemsPerSegment, q.len)
    result.add q[w ..< top]

# ------------------------------------------------------------------------------
# Public functions, units pretty printer
# ------------------------------------------------------------------------------

proc ppMs*(elapsed: Duration): string =
  result = $elapsed.inMilliSeconds
  let ns = elapsed.inNanoSeconds mod 1_000_000
  if ns != 0:
    # to rounded deca milli seconds
    let dm = (ns + 5_000i64) div 10_000i64
    result &= &".{dm:02}"
  result &= "ms"

proc ppSecs*(elapsed: Duration): string =
  result = $elapsed.inSeconds
  let ns = elapsed.inNanoseconds mod 1_000_000_000
  if ns != 0:
    # to rounded decs seconds
    let ds = (ns + 5_000_000i64) div 10_000_000i64
    result &= &".{ds:02}"
  result &= "s"

proc toKMG*[T](s: T): string =
  proc subst(s: var string; tag, new: string): bool =
    if tag.len < s.len and s[s.len - tag.len ..< s.len] == tag:
      s = s[0 ..< s.len - tag.len] & new
      return true
  result = $s
  for w in [("000", "K"),("000K","M"),("000M","G"),("000G","T"),
            ("000T","P"),("000P","E"),("000E","Z"),("000Z","Y")]:
    if not result.subst(w[0],w[1]):
      return

# ------------------------------------------------------------------------------
# Public functions,  pretty printer
# ------------------------------------------------------------------------------

proc pp*(s: string; hex = false): string =
  if hex:
    let n = (s.len + 1) div 2
    (if s.len < 20: s else: s[0 .. 5] & ".." & s[s.len-8 .. s.len-1]) &
      "[" & (if 0 < n: "#" & $n else: "") & "]"
  elif s.len <= 30:
    s
  else:
    (if (s.len and 1) == 0: s[0 ..< 8] else: "0" & s[0 ..< 7]) &
      "..(" & $s.len & ").." & s[s.len-16 ..< s.len]

proc pp*(q: openArray[int]; itemsPerLine: int; lineSep: string): string =
  doAssert q == q.reGroup(itemsPerLine).concat
  q.reGroup(itemsPerLine)
   .mapIt(it.mapIt(&"0x{it:02x}").join(", "))
   .join("," & lineSep)

proc pp*(a: MDigest[256]; collapse = true): string =
  if not collapse:
    a.data.mapIt(it.toHex(2)).join.toLowerAscii
  elif a == EmptyRlpHash:
    "emptyRlpHash"
  elif a == EmptyUncleHash:
    "emptyUncleHash"
  elif a == EmptySha3:
    "EmptySha3"
  elif a == ZeroHash256:
    "zeroHash256"
  else:
    a.data.mapIt(it.toHex(2)).join[56 .. 63].toLowerAscii

proc pp*(a: openArray[MDigest[256]]; collapse = true): string =
  "@[" & a.toSeq.mapIt(it.pp).join(" ") & "]"

proc pp*(q: openArray[int]; itemsPerLine: int; indent: int): string =
  q.pp(itemsPerLine = itemsPerLine, lineSep = "\n" & " ".repeat(max(1,indent)))

proc pp*(q: openArray[byte]; noHash = false): string =
  if q.len == 32 and not noHash:
    var a: array[32,byte]
    for n in 0..31: a[n] = q[n]
    MDigest[256](data: a).pp
  else:
    q.toSeq.mapIt(it.toHex(2)).join.toLowerAscii.pp(hex = true)

# ------------------------------------------------------------------------------
# Elapsed time pretty printer
# ------------------------------------------------------------------------------

template showElapsed*(noisy: bool; info: string; code: untyped) =
  block:
    let start = getTime()
    code
    if noisy:
      let elpd {.inject.} = getTime() - start
      if 0 < times.inSeconds(elpd):
        echo "*** ", info, &": {elpd.ppSecs:>4}"
      else:
        echo "*** ", info, &": {elpd.ppMs:>4}"

template catchException*(info: string; trace: bool; code: untyped) =
  block:
    try:
      code
    except CatchableError as e:
      if trace:
        echo "*** ", info, ": exception ", e.name, "(", e.msg, ")"
        echo "    ", e.getStackTrace.strip.replace("\n","\n    ")

template catchException*(info: string; code: untyped) =
  catchException(info, false, code)

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------