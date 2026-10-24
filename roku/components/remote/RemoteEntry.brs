sub init()
    m.wall = m.top.findNode("wall")
    m.drift = m.top.findNode("drift")
    entryBrand(m.top.findNode("startupBrand"),88,104,22,104)
    entryBrand(m.top.findNode("welcomeBrand"),80,92,20)
    entryBrand(m.top.findNode("choiceBrand"),64,72,18)
end sub
sub entryBrand(parent as object, mark as float, size as float, gap as float, height = 0 as float)
    if height = 0 then height = size*1.2
    ground = parent.createChild("Poster")
    ground.uri = "pkg:/images/design/remote-brand-mark.png"
    ground.blendColor = "#F5C542"
    ground.width = mark
    ground.height = mark
    ground.translation = [0,(height-mark)/2]
    label = entryLabel(parent,"V",mark,mark,mark*.625,"#0B0B0C")
    label.translation = ground.translation
    label.horizAlign = "center"
    label.vertAlign = "center"
    positions = [0,54.464,73.14,123.372,167.164]
    for i = 0 to 4
        label = entryLabel(parent,mid("VIPTV",i+1,1),size,height,size,"#F4F2EE")
        label.translation = [mark+gap+positions[i]*size/92,0]
        label.vertAlign = "center"
    end for
end sub
function entryLabel(parent as object,text as string,width as float,height as float,size as float,color as string) as object
    node = parent.createChild("Label")
    node.text = text
    node.width = width
    node.height = height
    node.color = color
    font = CreateObject("roSGNode","Font")
    font.uri = "pkg:/fonts/remote_bricolage_800.ttf"
    font.size = size
    node.font = font
    return node
end function
sub render()
    if m.wall = invalid then return
    startup = m.top.mode = "startup"
    m.top.findNode("startup").visible = startup
    m.top.findNode("startupMotion").control = "stop"
    m.top.findNode("startupArrival").control = "stop"
    if startup
        m.top.findNode("startupMotion").control = "start"
        m.top.findNode("startupArrival").control = "start"
    end if
    welcome = m.top.mode = "welcome"
    m.top.findNode("welcome").visible = welcome
    m.top.findNode("choice").visible = m.top.mode = "choice"
    m.drift.control = "stop"
    if not welcome
        m.wall.removeChildrenIndex(m.wall.getChildCount(),0)
        return
    end if
    m.wall.translation = [0,0]
    if m.wall.getChildCount() = 0
        posters = [0,1,2,3,4,5,6,7,8,9,5,6,7,8,9,10,11,12,13,14,10,11,12,13,14,15,16,17,0,1,15,16,17,0,1,2,3,4,5,6]
        for i = 0 to posters.count()-1
            art = m.wall.createChild("Poster")
            art.translation = [-60+(i mod 10)*252,-100+int(i/10)*372]
            art.width = 236
            art.height = 354
            art.loadWidth = 236
            art.loadHeight = 354
            art.opacity = 0.32
            art.loadDisplayMode = "scaleToZoom"
            art.uri = "pkg:/images/design/remote-entry-tile-"+posters[i].toStr()+".png"
        end for
    end if
    m.drift.control = "start"
end sub
