# SVG mapper

Utilizing [node-canvas](https://github.com/learnboost/node-canvas) and [CanVG](http://code.google.com/p/canvg/) slices provided SVG into tiles for use e.g. in [Leaflet](http://leafletjs.com/). Supports [UTFGrid](https://www.mapbox.com/developers/utfgrid/). Written in [LiveScript](http://livescript.net/), compiles to JavaScript.

Please note it is quite resource intensive (easily takes a gigabyte of RAM per thread) and **does not support CSS** styled content, all elements must have all their properties set by inline attributes.

## Usage in a nutshell

* Draw SVG with D3.geo.mercator projection. Annotate it with **data-bounds** attribute, indicating its maximum north, west, south and east coordinates.
* For each required path (geo/topoJSON feature), add **data-export** attribute with stringified JSON of the interactive data (what should be displayed on hover, what should be done on click etc.)
* Run the command-line utility to generate tiles - both imagery and UTFGrid JSONs
* Integrate the new layer into your existing Leaflet deployment. You might want [Leaflet.utfgrid](https://github.com/danzel/Leaflet.utfgrid) if you don't use it already.

## Step by step usage

Firsty, you need the annoted SVG. For an example how to generate one from geoJSON and some predefined data, see (example/generator.html)[./example/generator.html]. You can get the SVG itself from that page using [SVG Crowbar](http://nytimes.github.io/svg-crowbar/) or download it [directly from the examples folder](./example/example.svg).

Now you need to run the command line map.ls

    lsc map.ls -f path/to/example.svg -z 6

lsc is a command to launch Node with automatic LiveScript compiler. You can also compile the LiveScripts to JavaScript and use plain node map.js. Map.ls takes following parameters:

* f - path to file
* z - zoomlevel to generate (same numbering as OpenStreetMap or Google Maps)

Now your tiles should be generated into a directory with the same name as the original SVG, sans the ".svg" suffix - see[example/output](example/output) directory. It is ready to be plugged into Leaflet as any other layer. See the (output example)[example/leaflet.html] for details on how to do this.

## Modus operandi
First of all, map.ls renders your image to a canvas with correct scale for a given zoom level and with appropriate offset from top and left sides to correctly align with Web Mercator tiles. See [this image](example/big.png) for an example of Czech Republic at zoomlevel 6.

Then, the UTFGrid needs to be generated. The biggest issue here is area detection - with possible overlaying paths, it can get quite complex. This is why SVGMapper uses color based detection on a rendered SVG rather than computational point-in-polygon detection. First, it selects all paths with data-export attribute and changes their fill color to a unique shade. This shade is later detected on a per-pixel basis and appropriate UTFGrid JSON is generated. For an example of how this works, see [this image](example/big_dataContoured.png).

Note that due to rendering antialiasing, there is a *colorInterval* property in [TileJsonGenerator](ls/TileJsonGenerator.ls) that dictates the minimum step between two shades. By default it is set to 5, meaning you can use 256^3 / 5 = **3.3M different export values**. Also note that same export values share the same shade, as seen in the [image above](example/big_dataContoured.png) with the westernmost area (*Karlovarsky region*) and the very center area (*Prague region*). That image also has the colorInterval bumped to 18 for increased clarity and human readability.

## Common errors
* Unexpected token when running map.ls - this hapens when the data-export is not valid JSON string. Make sure to use JSON.stringify on any data-export values.

## TODO

- Documentation

## Licence (MIT)
Copyright (c) 2013 Economia, a.s.

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
