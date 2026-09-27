' Explicit circle geometry avoids device-dependent nine-patch cap scaling.
' Border and fill share a contour entirely inside the native grid item.
sub init()
    m.layers = []
    for each id in ["border","fill"]
        group = m.top.findNode(id)
        nodes = []
        for i = 0 to 5
            kind = "Poster"
            if i >= 4 then kind = "Rectangle"
            node = group.createChild(kind)
            if i < 4 then node.uri = "pkg:/images/design/circle.png"
            nodes.push(node)
        end for
        m.layers.push(nodes)
    end for
    render()
end sub
sub render()
    if m.layers = invalid then return
    w = m.top.width
    h = m.top.height
    r = m.top.radius
    if r < 0 then r = h/2
    if r > h/2 then r = h/2
    if r > w/2 then r = w/2
    m.top.findNode("border").visible = m.top.focused
    for layer = 0 to 1
        inset = 0
        color = "#FFFFFFFF"
        if layer = 1
            color = m.top.blendColor
            if m.top.focused then inset = 3
        end if
        diameter = 2*(r-inset)
        rects = [[inset,inset,diameter,diameter],[w-inset-diameter,inset,diameter,diameter],[inset,h-inset-diameter,diameter,diameter],[w-inset-diameter,h-inset-diameter,diameter,diameter],[r,inset,w-2*r,h-2*inset],[inset,r,w-2*inset,h-2*r]]
        for i = 0 to 5
            node = m.layers[layer][i]
            bounds = rects[i]
            node.translation = [bounds[0],bounds[1]]
            node.width = bounds[2]
            node.height = bounds[3]
            node.visible = bounds[2] > 0 and bounds[3] > 0
            if i < 4 then node.blendColor = color else node.color = color
        end for
    end for
end sub
