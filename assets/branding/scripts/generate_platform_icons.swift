import AppKit
import Foundation

let fileManager = FileManager.default

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let scriptsDir = scriptURL.deletingLastPathComponent()
let brandingDir = scriptsDir.deletingLastPathComponent()
let repoRoot = brandingDir.deletingLastPathComponent().deletingLastPathComponent()

let exportDir = brandingDir.appendingPathComponent("export")
let macosIconsetDir = exportDir.appendingPathComponent("macos/AppIcon.appiconset")
let windowsPngDir = exportDir.appendingPathComponent("windows/png")
let windowsIcoDir = exportDir.appendingPathComponent("windows/ico")
let linuxHicolorDir = exportDir.appendingPathComponent("linux/hicolor")

let desktopMacosIconsetDir = repoRoot.appendingPathComponent(
  "desktop/macos/Runner/Assets.xcassets/AppIcon.appiconset"
)
let desktopWindowsIconURL = repoRoot.appendingPathComponent(
  "desktop/windows/runner/resources/app_icon.ico"
)
let desktopLinuxResourcesDir = repoRoot.appendingPathComponent(
  "desktop/linux/runner/resources"
)
let desktopLinuxHicolorDir = desktopLinuxResourcesDir.appendingPathComponent(
  "hicolor"
)
let desktopLinuxDesktopFileURL = desktopLinuxResourcesDir.appendingPathComponent(
  "dev.pi.pi_desktop.desktop"
)

let macosSizes = [16, 32, 64, 128, 256, 512, 1024]
let windowsSizes = [16, 24, 32, 48, 64, 128, 256]
let linuxSizes = [16, 24, 32, 48, 64, 128, 256, 512]

let topStroke: [(CGFloat, CGFloat)] = [
  (52, 85),
  (69, 71), (98, 64), (132, 64),
  (161, 64), (184, 68), (201, 78),
  (200, 89), (193, 96), (181, 100),
  (166, 92), (146, 89), (124, 89),
  (99, 89), (78, 93), (61, 100),
  (55, 99), (52, 93), (52, 85),
]

let leftStem: [(CGFloat, CGFloat)] = [
  (82, 89),
  (92, 86), (101, 92), (106, 103),
  (99, 126), (99, 155), (106, 186),
  (101, 191), (94, 194), (84, 193),
  (77, 160), (76, 123), (82, 89),
]

let rightStem: [(CGFloat, CGFloat)] = [
  (149, 88),
  (160, 84), (170, 88), (177, 97),
  (170, 116), (168, 136), (170, 153),
  (172, 169), (177, 181), (188, 190),
  (186, 198), (178, 203), (165, 204),
  (154, 198), (149, 187), (147, 168),
  (145, 149), (145, 122), (149, 88),
]

struct IconStyle {
  let insetRatio: CGFloat
  let cornerRatio: CGFloat
  let symbolScale: CGFloat
  let yShift: CGFloat
}

let sharedStyle = IconStyle(
  insetRatio: 0.07,
  cornerRatio: 0.21,
  symbolScale: 1.06,
  yShift: 1.0
)

func ensureDirectory(_ url: URL) throws {
  try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
}

func removeIfExists(_ url: URL) throws {
  if fileManager.fileExists(atPath: url.path) {
    try fileManager.removeItem(at: url)
  }
}

func symbolPoint(
  _ x: CGFloat,
  _ y: CGFloat,
  size: CGFloat,
  scale: CGFloat,
  yShift: CGFloat
) -> CGPoint {
  let centerX: CGFloat = 128
  let centerY: CGFloat = 128
  let translatedX = ((x - centerX) * scale + centerX) / 256.0 * size
  let topY = ((y - centerY) * scale + centerY + yShift) / 256.0 * size
  return CGPoint(x: translatedX, y: size - topY)
}

func makePath(
  points: [(CGFloat, CGFloat)],
  size: CGFloat,
  style: IconStyle
) -> NSBezierPath {
  let path = NSBezierPath()
  guard let first = points.first else { return path }
  path.move(
    to: symbolPoint(
      first.0,
      first.1,
      size: size,
      scale: style.symbolScale,
      yShift: style.yShift
    )
  )

  var index = 1
  while index + 2 < points.count {
    let c1 = symbolPoint(
      points[index].0,
      points[index].1,
      size: size,
      scale: style.symbolScale,
      yShift: style.yShift
    )
    let c2 = symbolPoint(
      points[index + 1].0,
      points[index + 1].1,
      size: size,
      scale: style.symbolScale,
      yShift: style.yShift
    )
    let end = symbolPoint(
      points[index + 2].0,
      points[index + 2].1,
      size: size,
      scale: style.symbolScale,
      yShift: style.yShift
    )
    path.curve(to: end, controlPoint1: c1, controlPoint2: c2)
    index += 3
  }

  path.close()
  return path
}

func drawIcon(size: Int, style: IconStyle) throws -> Data {
  let pixel = CGFloat(size)
  let inset = max(1.0, pixel * style.insetRatio)
  let corner = pixel * style.cornerRatio

  guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: size * 4,
    bitsPerPixel: 32
  ) else {
    throw NSError(domain: "icon", code: 1)
  }

  rep.size = NSSize(width: pixel, height: pixel)

  NSGraphicsContext.saveGraphicsState()
  guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    throw NSError(domain: "icon", code: 2)
  }
  NSGraphicsContext.current = context
  context.cgContext.setShouldAntialias(true)
  context.imageInterpolation = .high

  NSColor.clear.setFill()
  NSBezierPath(rect: NSRect(x: 0, y: 0, width: pixel, height: pixel)).fill()

  let background = NSBezierPath(
    roundedRect: NSRect(
      x: inset,
      y: inset,
      width: pixel - inset * 2,
      height: pixel - inset * 2
    ),
    xRadius: corner,
    yRadius: corner
  )
  NSColor.black.setFill()
  background.fill()

  NSColor.white.setFill()
  makePath(points: topStroke, size: pixel, style: style).fill()
  makePath(points: leftStem, size: pixel, style: style).fill()
  makePath(points: rightStem, size: pixel, style: style).fill()

  NSGraphicsContext.restoreGraphicsState()

  guard let png = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "icon", code: 3)
  }

  return png
}

func write(_ data: Data, to url: URL) throws {
  try ensureDirectory(url.deletingLastPathComponent())
  try data.write(to: url, options: .atomic)
}

func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
  var little = value.littleEndian
  withUnsafeBytes(of: &little) { bytes in
    data.append(contentsOf: bytes)
  }
}

func buildIco(entries: [(size: Int, data: Data)]) -> Data {
  let sorted = entries.sorted { $0.size < $1.size }
  var ico = Data()
  appendLE(UInt16(0), to: &ico)
  appendLE(UInt16(1), to: &ico)
  appendLE(UInt16(sorted.count), to: &ico)

  var offset = 6 + sorted.count * 16
  for entry in sorted {
    let iconSize = entry.size == 256 ? 0 : UInt8(entry.size)
    ico.append(iconSize)
    ico.append(iconSize)
    ico.append(0)
    ico.append(0)
    appendLE(UInt16(1), to: &ico)
    appendLE(UInt16(32), to: &ico)
    appendLE(UInt32(entry.data.count), to: &ico)
    appendLE(UInt32(offset), to: &ico)
    offset += entry.data.count
  }

  for entry in sorted {
    ico.append(entry.data)
  }

  return ico
}

func generateMacosIconset() throws {
  try ensureDirectory(macosIconsetDir)

  for size in macosSizes {
    let data = try drawIcon(size: size, style: sharedStyle)
    let fileURL = macosIconsetDir.appendingPathComponent("app_icon_\(size).png")
    try write(data, to: fileURL)
  }

  let contentsJSON = """
{
  "images" : [
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "app_icon_16.png",
      "scale" : "1x"
    },
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "app_icon_32.png",
      "scale" : "2x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "app_icon_32.png",
      "scale" : "1x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "app_icon_64.png",
      "scale" : "2x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "app_icon_128.png",
      "scale" : "1x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "app_icon_256.png",
      "scale" : "2x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "app_icon_256.png",
      "scale" : "1x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "app_icon_512.png",
      "scale" : "2x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "app_icon_512.png",
      "scale" : "1x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "app_icon_1024.png",
      "scale" : "2x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
"""
  try write(
    contentsJSON.data(using: .utf8)!,
    to: macosIconsetDir.appendingPathComponent("Contents.json")
  )
}

func generateWindowsExports() throws {
  try ensureDirectory(windowsPngDir)
  try ensureDirectory(windowsIcoDir)

  var icoEntries: [(size: Int, data: Data)] = []
  for size in windowsSizes {
    let data = try drawIcon(size: size, style: sharedStyle)
    let fileURL = windowsPngDir.appendingPathComponent("app_icon_\(size).png")
    try write(data, to: fileURL)
    icoEntries.append((size: size, data: data))
  }

  let icoData = buildIco(entries: icoEntries)
  try write(icoData, to: windowsIcoDir.appendingPathComponent("app_icon.ico"))
}

func generateLinuxExports() throws {
  for size in linuxSizes {
    let data = try drawIcon(size: size, style: sharedStyle)
    let dirURL = linuxHicolorDir.appendingPathComponent("\(size)x\(size)/apps")
    let fileURL = dirURL.appendingPathComponent("pi-app.png")
    try write(data, to: fileURL)
  }
}

func syncMacosIconsetToDesktop() throws {
  try ensureDirectory(desktopMacosIconsetDir)
  for item in try fileManager.contentsOfDirectory(
    at: macosIconsetDir,
    includingPropertiesForKeys: nil
  ) {
    let target = desktopMacosIconsetDir.appendingPathComponent(item.lastPathComponent)
    try removeIfExists(target)
    try fileManager.copyItem(at: item, to: target)
  }
}

func syncWindowsIconToDesktop() throws {
  let source = windowsIcoDir.appendingPathComponent("app_icon.ico")
  try ensureDirectory(desktopWindowsIconURL.deletingLastPathComponent())
  try removeIfExists(desktopWindowsIconURL)
  try fileManager.copyItem(at: source, to: desktopWindowsIconURL)
}

func syncLinuxExportsToDesktop() throws {
  try removeIfExists(desktopLinuxHicolorDir)
  try ensureDirectory(desktopLinuxResourcesDir)

  let desktopFile = """
[Desktop Entry]
Name=Pi Desktop
Comment=GUI client for pi.dev agent
Exec=pi_desktop
Icon=dev.pi.pi_desktop
Terminal=false
Type=Application
Categories=Development;
StartupNotify=true
"""
  try write(
    desktopFile.data(using: .utf8)!,
    to: desktopLinuxDesktopFileURL
  )

  for size in linuxSizes {
    let source = linuxHicolorDir.appendingPathComponent(
      "\(size)x\(size)/apps/pi-app.png"
    )
    let targetDir = desktopLinuxHicolorDir.appendingPathComponent(
      "\(size)x\(size)/apps"
    )
    let target = targetDir.appendingPathComponent("dev.pi.pi_desktop.png")
    try ensureDirectory(targetDir)
    try removeIfExists(target)
    try fileManager.copyItem(at: source, to: target)
  }
}

try generateMacosIconset()
try generateWindowsExports()
try generateLinuxExports()
try syncMacosIconsetToDesktop()
try syncWindowsIconToDesktop()
try syncLinuxExportsToDesktop()

print("Generated branding exports:")
print("- \(macosIconsetDir.path)")
print("- \(windowsPngDir.path)")
print("- \(windowsIcoDir.path)")
print("- \(linuxHicolorDir.path)")
print("Synced desktop platform assets:")
print("- \(desktopMacosIconsetDir.path)")
print("- \(desktopWindowsIconURL.path)")
print("- \(desktopLinuxResourcesDir.path)")
