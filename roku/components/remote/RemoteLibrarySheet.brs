sub init()
    m.top.focusable = true
    for each id in ["scrim","panel","fields","buttons","menu","menuGround","menuRows","entrance","enterSlide","enterFade","exitMotion","exitSlide","exitFade"]
        m[id] = m.top.findNode(id)
    end for
    m.controls = []
    m.draft = {}
    m.field = 0
    m.button = 0
    m.menuIndex = 0
    m.mode = "fields"
    m.closing = false
    for i = 0 to 7
        row = m.fields.createChild("Group")
        caption = sheetLabel(row,22,"500",752,24)
        caption.translation = [0,-3]
        caption.color = "#B6B4AF"
        button = sheetButton(row,752)
        button.translation = [0,32]
        button.getChild(1).translation = [18,16]
        button.getChild(1).horizAlign = "left"
        button.getChild(1).width = 674
        icon = button.createChild("Poster")
        icon.translation = [710,20]
        icon.width = 24
        icon.height = 24
    end for
    for i = 0 to 1
        button = sheetButton(m.buttons,370)
        button.translation = [i*382,0]
        if i = 0 then button.getChild(1).text = "Clear" else button.getChild(1).text = "Apply"
    end for
    for i = 0 to 7
        row = m.menuRows.createChild("Group")
        row.translation = [0,i*64]
        ground = row.createChild("Rectangle")
        ground.height = 64
        ground.color = "#FFFFFF14"
        label = sheetLabel(row,24,"500",536,32)
        label.translation = [48,17]
        icon = row.createChild("Poster")
        icon.translation = [12,20]
        icon.width = 24
        icon.height = 24
        icon.uri = "pkg:/images/lucide/check-primary.png"
    end for
    m.keys = []
    m.enterCurve = []
    m.exitCurve = []
    for i = 0 to 60
        t = i/60
        m.keys.push(t)
        m.enterCurve.push(curve(t,0,0))
        m.exitCurve.push(curve(t,0.3,1))
    end for
    for each id in ["enterSlide","enterFade","exitSlide","exitFade"]
        m[id].key = m.keys
    end for
    m.exitMotion.observeField("state","exited")
    m.top.observeField("focusedChild","refresh")
end sub
function sheetLabel(parent as object,size as integer,weight as string,w as integer,h as integer) as object
    label = parent.createChild("Label")
    label.width = w
    label.height = h
    label.color = "#F4F2EE"
    font = CreateObject("roSGNode","Font")
    font.uri = "pkg:/fonts/remote_onest_"+weight+".ttf"
    font.size = size
    label.font = font
    return label
end function
function sheetButton(parent as object,w as integer) as object
    button = parent.createChild("Group")
    ground = button.createChild("Poster")
    ground.uri = "pkg:/images/design/remote-filter-action.9.png"
    ground.width = w
    ground.height = 64
    label = sheetLabel(button,24,"400",w,32)
    label.translation = [0,17]
    label.horizAlign = "center"
    ring = button.createChild("Poster")
    ring.uri = "pkg:/images/design/remote-filter-action-focus.9.png"
    ring.translation = [-4,-4]
    ring.width = w+8
    ring.height = 72
    return button
end function
function curve(t as float,x1 as float,x2 as float) as float
    if t = 0 or t = 1 then return t
    lo = 0.0
    hi = 1.0
    for i = 0 to 17
        u = (lo+hi)/2
        x = 3*(1-u)*(1-u)*u*x1+3*(1-u)*u*u*x2+u*u*u
        if x < t then lo = u else hi = u
    end for
    return 3*u*u-2*u*u*u
end function
sub open()
    m.top.findNode("resetError").text = ""
    m.closing = false
    m.entrance.control = "stop"
    m.exitMotion.control = "stop"
    m.controls = []
    for each control in RArray(m.top.controls)
        if control.id <> "source" and control.id <> "type" and RArray(control.choices).count() > 0 then m.controls.push(control)
    end for
    m.draft = RQueryFields(m.top.query)
    publish()
    m.field = 0
    m.button = 0
    m.mode = "fields"
    if m.controls.count() = 0 then m.mode = "buttons"
    m.menu.visible = false
    m.top.setFocus(true)
    positions = []
    for each p in m.enterCurve
        positions.push([1920-800*p,0])
    end for
    m.enterSlide.keyValue = positions
    m.enterFade.keyValue = m.enterCurve
    m.panel.translation = [1920,0]
    m.scrim.opacity = 0
    refresh()
    m.entrance.control = "start"
end sub
sub close()
    if m.closing then return
    m.closing = true
    m.entrance.control = "stop"
    x = m.panel.translation[0]
    opacity = m.scrim.opacity
    positions = []
    fades = []
    for each p in m.exitCurve
        positions.push([x+(1920-x)*p,0])
        fades.push(opacity*(1-p))
    end for
    m.exitSlide.keyValue = positions
    m.exitFade.keyValue = fades
    m.exitMotion.control = "start"
end sub
sub exited()
    if m.closing and m.exitMotion.state = "stopped" then m.top.dismissed = true
end sub
sub publish()
    m.top.draft = RCopy(m.draft)
end sub
function valueText(control as object) as string
    value = controlValue(control)
    for each choice in RArray(control.choices)
        if REqual(choice.value,value) then return choice.label
    end for
    if GetInterface(value,"ifString") <> invalid
        if value = "" then return "Any"
        return value
    end if
    return value.toStr()
end function
sub paintButton(button as object,focused as boolean)
    button.getChild(0).blendColor = "#39393A"
    button.getChild(1).color = "#F4F2EE"
    button.getChild(2).visible = focused and m.top.isInFocusChain()
    if focused
        button.getChild(0).blendColor = "#F4F2EE"
        button.getChild(1).color = "#0B0B0C"
    end if
end sub
sub refresh()
    if m.fields = invalid then return
    m.firstField = 0
    if m.field > 6 then m.firstField = m.field-6
    for slot = 0 to 7
        row = m.fields.getChild(slot)
        index = m.firstField+slot
        row.visible = index < m.controls.count()
        if row.visible
            control = m.controls[index]
            row.translation = [0,slot*116]
            row.getChild(0).text = control.label
            button = row.getChild(1)
            button.getChild(1).text = valueText(control)
            focused = m.field = index and (m.mode = "fields" or m.mode = "menu")
            paintButton(button,focused)
            variant = "primary"
            if focused then variant = "focus"
            button.getChild(3).visible = RArray(control.choices).count() > 0
            button.getChild(3).uri = "pkg:/images/lucide/library-chevron-"+variant+".png"
        end if
    end for
    for i = 0 to 1
        paintButton(m.buttons.getChild(i),m.mode = "buttons" and m.button = i)
    end for
    if m.mode <> "menu" then return
    choices = RArray(m.controls[m.field].choices)
    viewport = m.menuGround.height-16
    m.menuScroll = 0
    if m.menuMoved then m.menuScroll = m.menuIndex*64
    maximum = choices.count()*64-viewport
    if maximum < 0 then maximum = 0
    if m.menuScroll > maximum then m.menuScroll = maximum
    first = int(m.menuScroll/64)
    inset = m.menuScroll-first*64
    for slot = 0 to 7
        row = m.menuRows.getChild(slot)
        index = first+slot
        row.visible = index < choices.count()
        row.translation = [0,slot*64-inset]
        if row.visible
            row.getChild(0).width = m.menuGround.width
            row.getChild(0).visible = m.menuMoved and index = m.menuIndex
            row.getChild(1).width = m.menuGround.width-60
            row.getChild(1).text = choices[index].label
            row.getChild(2).visible = REqual(controlValue(m.controls[m.field]),choices[index].value)
        end if
    end for
end sub
sub chooseField()
    control = m.controls[m.field]
    choices = RArray(control.choices)
    if choices.count() = 0 then return
    m.menuIndex = 0
    m.menuScroll = 0
    m.menuMoved = false
    w = 260
    measure = sheetLabel(m.menuRows,24,"500",0,32)
    for i = 0 to choices.count()-1
        measure.text = choices[i].label
        if measure.boundingRect().width+60 > w then w = measure.boundingRect().width+60
    end for
    m.menuRows.removeChild(measure)
    if w > 600 then w = 600
    h = choices.count()*64+16
    if h > 480 then h = 480
    y = 181+(m.field-m.firstField)*116
    if y+h > 1056 then y = 117+(m.field-m.firstField)*116-h
    if y < 24 then y = 24
    m.menu.translation = [24,y]
    m.menuGround.width = w
    m.menuGround.height = h
    m.menuRows.clippingRect = [0,0,w,h-16]
    m.mode = "menu"
    m.menu.visible = true
    refresh()
end sub
function onKeyEvent(key as string,press as boolean) as boolean
    if not press then return false
    if m.closing then return true
    if key = "back"
        if m.mode = "menu"
            m.menu.visible = false
            m.mode = "fields"
        else
            close()
        end if
    else if m.mode = "menu"
        choices = RArray(m.controls[m.field].choices)
        if key = "up" or key = "down"
            if not m.menuMoved
                if key = "down" then m.menuIndex = 0 else m.menuIndex = choices.count()-1
            else if key = "up"
                m.menuIndex--
                if m.menuIndex < 0 then m.menuIndex = choices.count()-1
            else
                m.menuIndex++
                if m.menuIndex >= choices.count() then m.menuIndex = 0
            end if
            m.menuMoved = true
        end if
        if key = "OK"
            if not m.menuMoved then return false
            value = choices[m.menuIndex].value
            if REqual(value,"") then m.draft.delete(m.controls[m.field].id) else m.draft[m.controls[m.field].id] = value
            publish()
            m.menu.visible = false
            m.mode = "fields"
        end if
    else if m.mode = "fields"
        if key = "up" and m.field > 0 then m.field--
        if key = "down"
            if m.field < m.controls.count()-1 then m.field++ else m.mode = "buttons"
        end if
        if key = "OK" then chooseField()
    else
        if key = "left" then m.button = 0
        if key = "right" then m.button = 1
        if key = "up" and m.controls.count() > 0 then m.mode = "fields"
        if key = "OK"
            if m.button = 0
                m.draft = RQueryFields(m.top.defaultQuery)
                m.top.error = ""
                publish()
            else
                m.top.submitted = true
            end if
        end if
    end if
    refresh()
    return true
end function

sub release()
    m.top.visible = false
    m.closing = false
    m.entrance.control = "stop"
    m.exitMotion.control = "stop"
    m.controls = []
    m.draft = {}
    m.top.controls = []
    m.top.query = {}
    m.top.defaultQuery = {}
    m.top.draft = {}
    m.top.error = ""
    m.menu.visible = false
    for each row in m.fields.getChildren(-1,0)
        row.getChild(0).text = ""
        row.getChild(1).getChild(1).text = ""
        row.visible = false
    end for
    for each row in m.menuRows.getChildren(-1,0)
        row.getChild(1).text = ""
        row.visible = false
    end for
end sub

function controlValue(control as object) as string
    value = RGet(m.draft,control.id,"")
    if GetInterface(value,"ifString") <> invalid then return value
    return value.toStr()
end function
