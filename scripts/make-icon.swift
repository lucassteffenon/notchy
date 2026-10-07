// Recorta o ícone gerado (squircle sobre fundo claro), aplica máscara transparente
// e centraliza na grade de ícones do macOS (824px de arte num canvas de 1024px).
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let src = NSImage(contentsOfFile: args[1]),
      let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("uso: make-icon.swift <entrada.png> <saida.png>"); exit(1)
}

// Bounding box dos pixels escuros (o squircle)
let w = cg.width, h = cg.height
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
let px = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h { for x in 0..<w {
    let i = (y * w + x) * 4
    let lum = (Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2])) / 3
    if lum < 120 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
}}
// Linhas do buffer estão de baixo para cima no CGContext: converte para recorte do CGImage
let crop = CGRect(x: minX, y: h - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
// Recorta um pouco para dentro, para não pegar a borda clara/sombra do fundo
let art = cg.cropping(to: crop.insetBy(dx: 14, dy: 14).integral)!

let canvas = 1024, artSize: CGFloat = 824, inset = (CGFloat(canvas) - artSize) / 2
let out = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: canvas * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let rect = CGRect(x: inset, y: inset, width: artSize, height: artSize)
let radius = artSize * 0.29
out.addPath(CGPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerWidth: radius, cornerHeight: radius, transform: nil))
out.clip()
out.interpolationQuality = .high
out.draw(art, in: rect)
let rep = NSBitmapImageRep(cgImage: out.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("bbox \(crop) -> \(args[2])")
