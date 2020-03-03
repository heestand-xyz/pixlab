# pixlab

Powered by [PixelKit](https://github.com/hexagons/pixelkit) and Metal

![](https://github.com/hexagons/pixlab/blob/master/Assets/Demos/pixlab_demo0.gif?raw=true)

## Install

Add [pixlab](https://github.com/hexagons/pixlab/raw/master/pixlab) to `/usr/local/bin/`

## Examples

~~~~
$ pixlab ~/Desktop/pix_out.png --metal-lib ~/PixelKitShaders-macOS.metallib --view
RenderKit ready to render.
> a = /Users/<user>/Desktop/pix_in_a.png
> b = /Users/<user>/Desktop/pix_in_b.png
> a + b
> a * b
> a -> b
> a ~> 0.1
> :q!
~~~~

~~~~
$ pixlab ~/Desktop/pix_out.png --metal-lib ~/PixelKitShaders-macOS.metallib --view
RenderKit ready to render.
> ramp = gradient(1024)
> ramp.
.scale
.offset
.bgColor
.color
.position
.direction
> ramp.direction = .
.horizontal
.vertical
.radial
.angle
> ramp.direction = .angle
> ramp
~~~~

~~~~
$ pixlab ~/Desktop/pix_out.png --metal-lib ~/PixelKitShaders-macOS.metallib --view
RenderKit ready to render.
> ? 
arc(res)
circle(res)
color(res)
gradient(res)
line(res)
noise(res)
polygon(res)
rectangle(res)
blur(pix)
channelmix(pix)
chromakey(pix)
clamp(pix)
cornerpin(pix)
edge(pix)
flare(pix)
flipflop(pix)
huesaturation(pix)
kaleidoscope(pix)
levels(pix)
quantize(pix)
range(pix)
sepia(pix)
sharpen(pix)
slope(pix)
threshold(pix)
transform(pix)
twirl(pix)
blend(pixA, pixB)
cross(pixA, pixB)
displace(pixA, pixB)
lookup(pixA, pixB)
lumablur(pixA, pixB)
lumalevels(pixA, pixB)
remap(pixA, pixB)
reorder(pixA, pixB)
array(pixA, pixB, pixC, ...)
blends(pixA, pixB, pixC, ...)
~~~~

You can find the Metal library [here](https://github.com/hexagons/PixelKit/tree/master/Resources/Metal%20Libs)
