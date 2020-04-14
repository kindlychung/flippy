import images, snappy, streams, strformat, strutils

export images

const version = 1

type Flippy* = object
  mipmaps*: seq[Image]

func width*(flippy: Flippy): int =
  flippy.mipmaps[0].width

func height*(flippy: Flippy): int =
  flippy.mipmaps[0].height

proc save*(flippy: Flippy, filePath: string) =
  ## Flippy is a special file format that is fast to load and save with mip maps.
  var f = newFileStream(filePath, fmWrite)
  defer: f.close()

  f.write(&"flippy!!0x{version.toHex(4)}\0")
  for mip in flippy.mipmaps:
    var zipped = snappy.compress(mip.data)
    f.write("mip!")
    f.write(mip.width.uint32)
    f.write(mip.height.uint32)
    f.write(len(zipped).uint32)
    f.writeData(zipped[0].addr, len(zipped))

proc pngToFlippy*(pngPath, flippyPath: string) =
  var
    image = loadImage(pngPath)
    flippy = Flippy()
  image.alphaBleed()
  var mip = image
  while true:
    flippy.mipmaps.add mip
    if mip.width == 1 or mip.height == 1:
      break
    mip = mip.minify(2)
  flippy.save(flippyPath)

proc loadFlippy*(filePath: string): Flippy =
  ## Flippy is a special file format that is fast to load and save with mip maps.
  var f = newFileStream(filePath, fmRead)
  defer: f.close()

  if f.readStr(15) != &"flippy!!0x{version.toHex(4)}\0":
    raise newException(Exception, &"Invalid Flippy header {filePath}.")

  while not f.atEnd():
    if f.readStr(4) != "mip!":
      raise newException(Exception, &"Invalid Flippy sub header {filePath}.")

    var mip = Image()
    mip.width = int f.readUint32()
    mip.height = int f.readUint32()
    mip.channels = 4
    let zippedLen = f.readUint32().int
    var zipped = newSeq[uint8](zippedLen)
    let read = f.readData(zipped[0].addr, zippedLen)
    if read != zippedLen:
      raise newException(Exception, "Flippy read error.")
    mip.data = snappy.uncompress(zipped)
    result.mipmaps.add(mip)
