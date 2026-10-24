sub init()
    m.glyphs = m.top.findNode("glyphs")
    ' Fractional advances from the pinned KMP Onest hmtx tables.
    m.metrics = {}
    m.extraMetrics = {}
    m.metrics["400"] = [0.27,0.273,0.359,0.653,0.656,0.804,0.677,0.222,0.308,0.308,0.414,0.55,0.261,0.458,0.254,0.477,0.665,0.363,0.566,0.599,0.633,0.616,0.623,0.505,0.622,0.62,0.253,0.261,0.55,0.55,0.55,0.513,0.983,0.67,0.655,0.704,0.72,0.61,0.599,0.72,0.727,0.261,0.558,0.625,0.574,0.856,0.741,0.761,0.63,0.761,0.658,0.652,0.569,0.726,0.683,0.983,0.593,0.614,0.597,0.321,0.477,0.321,0.55,0.463,0.559,0.555,0.604,0.553,0.604,0.573,0.366,0.604,0.591,0.219,0.254,0.52,0.219,0.819,0.591,0.595,0.604,0.604,0.373,0.509,0.37,0.576,0.536,0.843,0.515,0.597,0.518,0.389,0.261,0.389,0.55]
    m.extraMetrics["400"] = {"8212":0.759,"8217":0.261,"8230":0.697,"183":0.249}
    m.metrics["500"] = [0.274,0.283,0.377,0.662,0.658,0.831,0.69,0.23,0.323,0.323,0.43,0.564,0.274,0.46,0.263,0.489,0.663,0.372,0.564,0.604,0.634,0.616,0.623,0.507,0.623,0.62,0.263,0.274,0.564,0.564,0.564,0.519,0.987,0.684,0.662,0.707,0.723,0.614,0.601,0.724,0.732,0.272,0.567,0.641,0.581,0.87,0.749,0.765,0.638,0.765,0.668,0.655,0.578,0.73,0.694,0.99,0.618,0.637,0.604,0.332,0.489,0.332,0.564,0.457,0.576,0.559,0.611,0.556,0.611,0.574,0.372,0.611,0.596,0.23,0.259,0.533,0.23,0.83,0.596,0.596,0.611,0.611,0.38,0.51,0.369,0.579,0.543,0.851,0.53,0.603,0.515,0.394,0.268,0.394,0.564]
    m.extraMetrics["500"] = {"8212":0.778,"8217":0.272,"8230":0.718,"183":0.261}
    m.metrics["700"] = [0.282,0.304,0.412,0.681,0.663,0.886,0.717,0.247,0.354,0.354,0.463,0.592,0.301,0.465,0.281,0.512,0.66,0.39,0.561,0.613,0.637,0.615,0.624,0.512,0.625,0.621,0.284,0.301,0.592,0.592,0.592,0.53,0.994,0.711,0.677,0.714,0.73,0.621,0.604,0.732,0.743,0.293,0.584,0.672,0.594,0.899,0.766,0.773,0.653,0.774,0.689,0.66,0.595,0.737,0.715,1.004,0.669,0.682,0.617,0.353,0.512,0.353,0.592,0.444,0.609,0.568,0.624,0.562,0.625,0.575,0.384,0.625,0.605,0.251,0.268,0.559,0.251,0.852,0.605,0.599,0.624,0.625,0.393,0.513,0.366,0.585,0.558,0.867,0.56,0.616,0.51,0.403,0.283,0.403,0.592]
    m.extraMetrics["700"] = {"8212":0.816,"8217":0.295,"8230":0.761,"183":0.284}
    render()
end sub
sub render()
    if m.glyphs = invalid then return
    m.advances = m.metrics[m.top.weight]
    m.glyphs.removeChildrenIndex(m.glyphs.getChildCount(),0)
    x = 0.0
    y = 0.0
    if m.top.rowHeight > 0 then y = (m.top.rowHeight-m.top.size*1.4)/2
    if m.top.rowWidth > 0
        width = 0.0
        for i = 0 to len(m.top.text)-1
            width += advance(mid(m.top.text,i+1,1))*m.top.size
        end for
        width += (len(m.top.text)-1)*m.top.tracking
        x = (m.top.rowWidth-width)/2
    end if
    for i = 0 to len(m.top.text)-1
        label = m.glyphs.createChild("Label")
        label.text = mid(m.top.text,i+1,1)
        label.translation = [x,y]
        label.width = m.top.size*2
        label.height = m.top.size*1.4
        label.color = m.top.textColor
        nativeFont = CreateObject("roSGNode","Font")
        nativeFont.uri = "pkg:/fonts/remote_onest_"+m.top.weight+".ttf"
        nativeFont.size = m.top.size
        label.font = nativeFont
        x += advance(label.text)*m.top.size+m.top.tracking
    end for
end sub

function advance(character as string) as float
    code = asc(character)
    if code >= 32 and code <= 126 then return m.advances[code-32]
    extra = m.extraMetrics[m.top.weight][code.toStr()]
    if extra <> invalid then return extra
    return 0.5
end function
sub paint()
    if m.glyphs = invalid then return
    for each label in m.glyphs.getChildren(-1,0)
        label.color = m.top.textColor
    end for
end sub
