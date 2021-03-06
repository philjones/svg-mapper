L = null
module.exports.generateMetadata = (svgAddress, targetDir, cb) ->
    require! <[ fs async ]>
    (err, {originalImage, contouredExportsImage, exportables, bounds}) <~ prepareSvgs svgAddress
    data = JSON.stringify {exportables, bounds}
    <~ async.parallel do
        *   -> fs.writeFile "#targetDir/original.svg", originalImage, it
            -> fs.writeFile "#targetDir/exports.svg", contouredExportsImage, it
            -> fs.writeFile "#targetDir/data.json", data, it
    cb?!

module.exports.getZoomlevelData = (bounds, subMaxWidth, subMaxHeight, zoomLevel) ->
    {width, height, firstTileNumberX, lastTileNumberX} = getPixelDimensions do
        bounds
        zoomLevel
    xSteps = Math.ceil width / subMaxWidth
    ySteps = Math.ceil height / subMaxHeight
    {zoomLevel, xSteps, ySteps, firstTileNumberX, lastTileNumberX}

module.exports.createDirectories = (dir, zoomLevels, cb) ->
    require! <[ fs async ]>
    <~ async.each zoomLevels, ({zoomLevel, firstTileNumberX, lastTileNumberX}, cb) ->
        <~ fs.mkdir "#dir/#zoomLevel"
        <~ async.each [firstTileNumberX to lastTileNumberX], (x, cb) ->
            <~ fs.mkdir "#dir/#zoomLevel/#x"
            cb!
        cb!
    cb?!

module.exports.generateCommands = (dir, subSize, zoomLevels, {skipJsons=false, skipTiles=false}:options) ->
    commands = []
    for {zoomLevel, xSteps, ySteps} in zoomLevels
        for sub in [0 til xSteps * ySteps]
            if not skipJsons
                commands.push "node #__dirname/map.js -d #dir -z #zoomLevel -c #sub -m json -s #subSize"
            if not skipTiles
                commands.push "node #__dirname/map.js -d #dir -z #zoomLevel -c #sub -m image -s #subSize"
    commands

getPixelDimensions = module.exports.getPixelDimensions = ({north, west, east, south}, zoomLevel) ->
    # find what the pixel coordinates would be on a full world map at the given zoomlevel
    if not L
        throw new error "Leaflet is not prepared - call utils.prepareLeaflet and wait for it to finish before calling getPixelDimensions"
    {x:x0, y:y0} = L.CRS.EPSG3857.latLngToPoint do
        new L.LatLng north, west
        zoomLevel
    {x:x1, y:y1} = L.CRS.EPSG3857.latLngToPoint do
        new L.LatLng south, east
        zoomLevel

    # number of pixels the first pixel of the image is offset from the left-upper most corner of the left-uppermost tile
    offsetX = x0 % 256
    offsetY = y0 % 256
    # width and height of the full image that will be sliced into tiles
    width  = Math.abs x0 - x1
    height = Math.abs y0 - y1
    # numbering of the first tile - we won't usually start at the prime meridian, North Pole
    firstTileNumberX = Math.floor x0 / 256
    firstTileNumberY = Math.floor y0 / 256

    lastTileNumberX = Math.floor x1 / 256
    lastTileNumberY = Math.floor y1 / 256

    {width, height, firstTileNumberX, firstTileNumberY, lastTileNumberX, lastTileNumberY, offsetX, offsetY}

prepareLeaflet = module.exports.prepareLeaflet = (cb) ->
    # following globals are for Leaflet, which depends on them
    require! {
        jsdom.env
    }
    (err, window) <~ env "<div></div>"
    global.document  = window.document
    global.window    = window
    global.navigator = {userAgent: "webkit"}
    require! leaflet
    L := leaflet
    cb!

prepareSvgs = (svgAddress, cb) ->
    require! './TileJsonGenerator'
    (err, $content, $) <~ getPrepared$Svg svgAddress
    bounds                = extractBounds $content
    originalImage         = fixCdata $content.html!
    tileJsonGenerator     = new TileJsonGenerator
    computeToContouredExports $, $content, tileJsonGenerator
    contouredExportsImage = fixCdata $content.html!
    {exportables} = tileJsonGenerator
    cb null {originalImage, contouredExportsImage, exportables, bounds}

extractBounds = ($content) ->
    bounds                     = $content.find "svg" .attr \data-bounds
    if not bounds
        throw new Error 'data-bounds attribute of <svg> not found. Use eg. <svg data-bounds="51.05,12.09,48.55,18.85">'
    [north, west, south, east] = bounds.split /[, ;]/g .map parseFloat
    {north, west, south, east}

getPrepared$Svg = (svgAddress, cb) ->
    require! {
        jsdom.env
        fs
        jquery
    }
    (err, window) <~ env "<div></div>"
    $ = jquery window
    (err, content) <~ fs.readFile svgAddress
    content .= toString!
    $content = $ "<div></div>"
    $content.html content
    $content.find "style" .remove! # CSS styles are unsupported - they would interfere with color-based area detection
    cb null $content, $

computeToContouredExports = ($, $content, tileJsonGenerator) ->
    $exportables = $content.find "[data-export]"
    $exportables.each ->
        # assign each exportable area a unique color, which will then be used to match the area with the data
        $ele = $ @
        exportable = $ele.attr \data-export
        index = tileJsonGenerator.getExportableIndex exportable
        color = tileJsonGenerator.getColorByIndex index
        $ele.attr \fill color

fixCdata = (str) -> # for some reason, $.html mangles CDATA declaration
    str.replace "![CDATA[" "<![CDATA["
