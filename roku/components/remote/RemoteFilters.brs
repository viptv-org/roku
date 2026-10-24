sub init()
    m.top.focusable = true
    m.controls = []
    m.draft = {}
    m.labelMaps = []
    m.selectionSets = {}
    m.facets = m.top.findNode("facets")
    m.choices = m.top.findNode("choices")
    m.buttons = m.top.findNode("buttons")
    m.textEditor = m.top.findNode("textEditor")
    m.textField = m.top.findNode("textField")
    m.textKeyboard = m.top.findNode("textKeyboard")
    m.textClear = m.top.findNode("textClear")
    for each target in [m.facets,m.buttons,m.textField,m.textClear]
        target.focusable = true
    end for
    m.textKeyboard.observeField("text","textEdited")
    m.textKeyboard.observeField("exitUp","textUp")
    m.textKeyboard.observeField("exitLeft","textLeft")
    m.textKeyboard.observeField("exitDown","textDown")
    m.textKeyboard.observeField("cancelled","textCancel")
    m.syncText = false
    clearTile = filterTile(m.textClear,"action",200,64,24,"600")
    clearTile.getChild(1).text = "Clear"
    clearTile.getChild(1).horizAlign = "center"
    clearTile.getChild(1).translation = [0,16]
    clearTile.getChild(1).width = 200
    for i = 0 to 6
        filterTile(m.facets,"facet",640,80,26,"700")
    end for
    for i = 0 to 20
        filterTile(m.choices,"choice",200,64,24,"600")
    end for
    labels = ["Show results","Clear all","Cancel"]
    widths = [340,220,220]
    x = 0
    for i = 0 to 2
        tile = filterTile(m.buttons,"action",widths[i],72,26,"700")
        tile.translation = [x,0]
        tile.getChild(1).text = labels[i]
        tile.getChild(1).horizAlign = "center"
        tile.getChild(1).translation = [0,20]
        tile.getChild(1).width = widths[i]
        x += widths[i]+16
    end for
    m.top.observeField("focusedChild","refresh")
    m.region = "facets"
    m.facet = 0
    m.active = 0
    m.choice = 0
    m.button = 0
end sub
function filterTile(parent as object,shape as string,w as integer,h as integer,size as integer,weight as string) as object
    tile = parent.createChild("Group")
    tile.addFields({shape:shape})
    fill = tile.createChild("Poster")
    fill.uri = "pkg:/images/design/remote-filter-"+shape+".9.png"
    fill.width = w
    fill.height = h
    label = tile.createChild("Label")
    font = CreateObject("roSGNode","Font")
    font.uri = "pkg:/fonts/remote_onest_"+weight+".ttf"
    font.size = size
    label.font = font
    label.height = 32
    label.translation = [24,16]
    value = tile.createChild("Label")
    value.translation = [314,24]
    value.width = 300
    value.height = 32
    value.horizAlign = "right"
    small = CreateObject("roSGNode","Font")
    small.uri = "pkg:/fonts/remote_onest_400.ttf"
    small.size = 22
    value.font = small
    check = tile.createChild("Poster")
    check.width = 22
    check.height = 22
    check.uri = "pkg:/images/lucide/check-focus.png"
    check.visible = false
    ring = tile.createChild("Poster")
    ring.uri = "pkg:/images/design/remote-filter-"+shape+"-focus.9.png"
    ring.translation = [-4,-4]
    ring.width = w+8
    ring.height = h+8
    ring.blendColor = "#FFFFFFFF"
    ring.visible = false
    if shape = "facet"
        required = tile.createChild("Label")
        required.text = "Required"
        required.height = 26
        required.width = 100
        f = CreateObject("roSGNode","Font")
        f.uri = "pkg:/fonts/remote_onest_600.ttf"
        f.size = 18
        required.font = f
        required.visible = false
    end if
    return tile
end function
sub open()
    m.controls = RArray(m.top.controls)
    m.labelMaps = []
    for each control in m.controls
        labels = CreateObject("roAssociativeArray")
        labels.setModeCaseSensitive()
        for each choice in RArray(control.choices)
            labels[choice.value] = choice.label
        end for
        m.labelMaps.push(labels)
    end for
    setDraft(RCopy(m.top.draft))
    m.region = "facets"
    if RArray(m.controls).count() = 0 then m.region = "buttons"
    m.facet = 0
    m.active = 0
    m.choice = 0
    m.button = 0
    m.top.resetCatalog = false
    m.textKeyboard.callFunc("resetEntry")
    m.facets.setFocus(true)
    refresh()
    if RArray(m.controls).count() > 0
        if RArray(m.controls[0].choices).count() = 0 then focusText()
    end if
end sub
function selected(control as object) as object
    return RArray(RGet(m.draft,control.id))
end function
function contains(values as object,value as string) as boolean
    for each item in values
        if item = value then return true
    end for
    return false
end function
sub style(tile as object,focused as boolean,checked as boolean,enabled = true as boolean)
    tile.getChild(0).blendColor = "#FFFFFF14"
    tile.getChild(1).color = "#F4F2EE"
    tile.getChild(2).color = "#B6B4AF"
    if tile.shape = "facet" then tile.getChild(0).blendColor = "#FFFFFF0A"
    if tile.shape = "action" then tile.getChild(0).blendColor = "#F4F2EE29"
    if checked and tile.shape = "facet" then tile.getChild(0).blendColor = "#FFFFFF29"
    if not enabled then tile.getChild(0).blendColor = "#FFFFFF0A"
    if focused or (checked and tile.shape = "choice")
        tile.getChild(0).blendColor = "#F4F2EE"
        tile.getChild(1).color = "#0B0B0C"
        tile.getChild(2).color = "#4A4945"
    end if
    if tile.shape = "facet" then tile.getChild(5).color = tile.getChild(2).color
    tile.getChild(4).visible = focused and m.top.isInFocusChain()
end sub
sub refresh()
    if m.facets = invalid then return
    controls = RArray(m.controls)
    if m.active >= controls.count() then m.active = 0
    first = 0
    if m.facet > 6 then first = m.facet-6
    for slot = 0 to 6
        tile = m.facets.getChild(slot)
        index = first+slot
        tile.visible = index < controls.count()
        if tile.visible
            control = controls[index]
            tile.translation = [0,slot*92]
            tile.getChild(1).translation = [26,24]
            tile.getChild(1).width = 280
            tile.getChild(1).text = RText(control.label)
            tile.getChild(5).visible = RGet(control,"required",false)
            if tile.getChild(5).visible
                tile.getChild(1).width = 0
                labelWidth = tile.getChild(1).boundingRect().width
                if labelWidth > 180 then labelWidth = 180
                tile.getChild(1).width = labelWidth
                tile.getChild(5).translation = [40+labelWidth,27]
            end if
            labels = []
            for each value in selected(control)
                label = value
                if m.labelMaps[index].doesExist(value) then label = m.labelMaps[index][value]
                labels.push(label)
            end for
            tile.getChild(2).text = labels.join(", ")
            if labels.count() = 0 then tile.getChild(2).text = "Any"
            style(tile,m.region = "facets" and m.facet = index,m.active = index)
        end if
    end for
    for each tile in m.choices.getChildren(-1,0)
        tile.visible = false
    end for
    m.textEditor.visible = false
    m.top.findNode("choiceHint").text = ""
    m.top.findNode("choiceCount").text = ""
    if controls.count() = 0
        m.top.findNode("choiceTitle").text = "No filters are available for this catalog."
    else
        control = controls[m.active]
        values = selected(control)
        choices = RArray(control.choices)
        m.top.findNode("choiceTitle").text = control.label
        count = values.count().toStr()+" selected"
        top = 312
        if control.maximum_selections <> invalid
            count = values.count().toStr()+" of "+control.maximum_selections.toStr()
            m.top.findNode("choiceHint").text = "Pick up to "+control.maximum_selections.toStr()+"."
            top = 344
        end if
        m.top.findNode("choiceCount").text = count
        m.choices.translation = [800,top]
        if choices.count() = 0
            m.top.findNode("choiceCount").text = "Enter a value"
            m.textEditor.visible = true
            value = values.join("")
            m.top.findNode("textValue").text = value
            m.top.findNode("textValue").color = "#F4F2EE"
            if value = ""
                m.top.findNode("textValue").text = control.label
                m.top.findNode("textValue").color = "#B6B4AF"
            end if
            m.syncText = true
            if m.textKeyboard.text <> value then m.textKeyboard.text = value
            m.syncText = false
            m.textClear.visible = value <> ""
            style(m.textClear.getChild(0),m.region = "textClear",false)
        else
            firstRow = 0
            if int(m.choice/3) > 6 then firstRow = int(m.choice/3)-6
            x = 0
            for slot = 0 to 20
                index = firstRow*3+slot
                if index < choices.count()
                    if slot mod 3 = 0 then x = 0
                    tile = m.choices.getChild(slot)
                    choice = choices[index]
                    checked = isSelected(control,choice.value)
                    tile.visible = true
                    tile.getChild(1).text = choice.label
                    tile.getChild(1).width = 0
                    w = tile.getChild(1).boundingRect().width+48
                    if checked then w += 34
                    if w < 200 then w = 200
                    if w > 320 then w = 320
                    tile.getChild(1).width = w-48
                    if checked then tile.getChild(1).width -= 34
                    tile.translation = [x,int(slot/3)*78]
                    tile.getChild(0).width = w
                    tile.getChild(4).width = w+8
                    tile.getChild(3).visible = checked
                    tile.getChild(3).translation = [w-46,21]
                    enabled = choiceEnabled(index)
                    style(tile,m.region = "choices" and m.choice = index,checked,enabled)
                    x += w+14
                end if
            end for
        end if
    end if
    for i = 0 to 2
        style(m.buttons.getChild(i),m.region = "buttons" and m.button = i,false)
    end for
end sub
sub toggle()
    control = m.controls[m.active]
    choices = RArray(control.choices)
    if choices.count() = 0
        focusText()
        return
    end if
    if m.choice >= choices.count() then return
    value = choices[m.choice].value
    values = selected(control)
    updated = []
    if control.kind = "MultiChoice"
        for each item in values
            if item <> value then updated.push(item)
        end for
        if not contains(values,value)
            if control.maximum_selections <> invalid
                if values.count() >= control.maximum_selections then return
            end if
            updated.push(value)
        end if
    else
        updated = [value]
    end if
    draft = RCopy(m.draft)
    draft[control.id] = updated
    setDraft(draft)
end sub
function choiceEnabled(index as integer) as boolean
    control = m.controls[m.active]
    choices = RArray(control.choices)
    if choices.count() = 0 then return index = 0
    if index < 0 or index >= choices.count() then return false
    values = selected(control)
    if control.kind <> "MultiChoice" or isSelected(control,choices[index].value) then return true
    if control.maximum_selections = invalid then return true
    return values.count() < control.maximum_selections
end function
sub moveChoice(key as string)
    count = RArray(m.controls[m.active].choices).count()
    if count = 0 then count = 1
    row = int(m.choice/3)
    column = m.choice mod 3
    candidate = -1
    best = 1000000
    for index = 0 to count-1
        if choiceEnabled(index)
            nextRow = int(index/3)
            nextColumn = index mod 3
            eligible = false
            if key = "left" then eligible = nextRow = row and nextColumn < column
            if key = "right" then eligible = nextRow = row and nextColumn > column
            if key = "up" then eligible = nextRow < row
            if key = "down" then eligible = nextRow > row
            score = abs(nextRow-row)*10+abs(nextColumn-column)
            if eligible and score < best
                candidate = index
                best = score
            end if
        end if
    end for
    if candidate >= 0
        m.choice = candidate
    else if key = "left"
        m.region = "facets"
    else if key = "down"
        m.region = "buttons"
    end if
end sub
function onKeyEvent(key as string,press as boolean) as boolean
    if not press then return false
    controls = RArray(m.controls)
    if key = "back"
        m.top.cancelled = true
    else if m.region = "facets"
        if key = "up" and m.facet > 0 then m.facet--
        if key = "down"
            if m.facet < controls.count()-1 then m.facet++ else m.region = "buttons"
        end if
        if key = "OK" or key = "right"
            m.active = m.facet
            m.choice = 0
            choices = RArray(controls[m.active].choices)
            if choices.count() = 0
                if not m.textEditor.visible then m.textKeyboard.callFunc("resetEntry")
                refresh()
                focusText()
            else if key = "right"
                m.region = "choices"
                for i = 0 to choices.count()-1
                    if choiceEnabled(i)
                        m.choice = i
                        exit for
                    end if
                end for
            end if
        end if
    else if m.region = "textField"
        if key = "OK" or key = "down" then focusText()
        if key = "left" then textLeft()
    else if m.region = "textClear"
        if key = "up" then focusText()
        if key = "left" then textLeft()
        if key = "down"
            m.region = "buttons"
            m.buttons.setFocus(true)
        end if
        if key = "OK"
            m.textKeyboard.text = ""
            focusText()
        end if
    else if m.region = "textKeyboard"
        return false
    else if m.region = "choices"
        if key = "OK"
            toggle()
        else if key = "left" or key = "right" or key = "up" or key = "down"
            moveChoice(key)
        end if
    else
        if key = "left" and m.button > 0 then m.button--
        if key = "right" and m.button < 2 then m.button++
        if key = "up" and controls.count() > 0 then m.region = "facets"
        if key = "OK"
            if m.button = 0
                m.top.submitted = true
            else if m.button = 1
                setDraft({})
                m.top.resetCatalog = true
            else
                m.top.cancelled = true
            end if
        end if
    end if
    refresh()
    return true
end function

sub focusText()
    m.region = "textKeyboard"
    m.textKeyboard.setFocus(true)
end sub
sub textEdited()
    if m.syncText or not m.textEditor.visible then return
    controls = RArray(m.controls)
    if m.active >= controls.count() then return
    draft = RCopy(m.draft)
    values = []
    if m.textKeyboard.text <> "" then values = [m.textKeyboard.text]
    draft[controls[m.active].id] = values
    setDraft(draft)
    refresh()
end sub
sub textUp()
    m.region = "textField"
    m.textKeyboard.setFocus(false)
    m.textField.setFocus(true)
    refresh()
end sub
sub textLeft()
    m.region = "facets"
    m.textKeyboard.setFocus(false)
    m.facets.setFocus(true)
    refresh()
end sub
sub textDown()
    m.textKeyboard.setFocus(false)
    m.region = "buttons"
    m.buttons.setFocus(true)
    if m.textKeyboard.text <> ""
        m.region = "textClear"
        m.textClear.setFocus(true)
    end if
    refresh()
end sub
sub textCancel()
    m.top.cancelled = true
end sub

sub setDraft(draft as dynamic)
    m.draft = draft
    if not RObject(m.draft) then m.draft = {}
    m.selectionSets = CreateObject("roAssociativeArray")
    m.selectionSets.setModeCaseSensitive()
    for each id in m.draft
        values = CreateObject("roAssociativeArray")
        values.setModeCaseSensitive()
        for each value in RArray(m.draft[id])
            values[value] = true
        end for
        m.selectionSets[id] = values
    end for
    m.top.draft = m.draft
end sub
function isSelected(control as object,value as string) as boolean
    values = RGet(m.selectionSets,control.id)
    if not RObject(values) then return false
    return values.doesExist(value)
end function

sub release()
    m.top.visible = false
    m.textEditor.visible = false
    m.controls = []
    m.draft = {}
    m.labelMaps = []
    m.selectionSets = {}
    m.top.controls = []
    m.top.draft = {}
    m.top.catalogLabel = ""
    m.textKeyboard.text = ""
    m.top.findNode("textValue").text = ""
    for each parent in [m.facets,m.choices]
        for each tile in parent.getChildren(-1,0)
            tile.getChild(1).text = ""
            tile.getChild(2).text = ""
            tile.visible = false
        end for
    end for
    m.top.findNode("choiceTitle").text = ""
    m.top.findNode("choiceCount").text = ""
    m.top.findNode("choiceHint").text = ""
end sub
