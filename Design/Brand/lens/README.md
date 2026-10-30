# Lens measurement

How the flat logo gets the same bend as the app icon's glass crystal.

1. `grad.icon`: a radial ramp (black at the center, white at radius 256) under a clear glass disc of radius 224 with refraction 0.15. Render it with `ictool` at `--scale 4`.
2. `table.swift` reads the render along eight directions and writes `table.txt`: for each display radius (0 to 240, step 0.5), the source radius the glass shows there. It is the identity out to 176; between 176 and 224 it rises to about 186.7 and folds back to about 153 at the rim.
3. `refract.swift source.png table.txt 224 out.d` pushes a high-resolution render of the flat line artwork through that map, traces the result with marching squares, simplifies it (0.12 units) and prints an SVG path in 1024 units.

`ramp.swift` and `scan.swift` are the spot checks used along the way (luminance along one ray; dark crossings of calibration rings).
