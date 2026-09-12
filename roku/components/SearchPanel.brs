sub init()
    m.keys = m.top.findNode("keys")
    m.results = m.top.findNode("resultsList")
    m.keys.observeField("text","changed")
    m.results.observeField("rowItemSelected","selected")
    m.keys.textEditBox.maxTextLength = 256
    m.keys.textEditBox.clearOnDownKey = false
    m.keys.textEditBox.hintText = "Search"
    m.keys.textEditBox.hintTextColor = "#A6A8AA"
    m.keys.textEditBox.textColor = "#F5F5F5"
    m.keys.textEditBox.backgroundUri = "pkg:/images/ui-input.9.png"
    m.keys.textEditBox.translation = [12,0]
    m.keys.textEditBox.width = 366
    m.keys.textEditBox.visible = false
end sub
sub open()
    m.opening = true
    m.keys.text = m.top.query
    m.opening = false
    updateQueryLabel()
    m.top.visible = true
    focusField()
end sub
sub focusField()
    m.keys.setFocus(true)
end sub
sub updateQueryLabel()
    value = m.keys.text
    if value = "" then value = "Search movies and shows"
    m.top.findNode("queryLabel").text = value
end sub
sub changed()
    updateQueryLabel()
    if m.opening <> true then m.top.query = m.keys.text
end sub
sub selected()
    m.top.selected = m.results.rowItemSelected
end sub
function onKeyEvent(key as string,press as boolean) as boolean
    if not press then return false
    if KeyboardMobileInput(m.keys,key)
        focusField()
        return true
    end if
    if key = "enter" or key = "play"
        focusResults()
        return true
    else if m.results.hasFocus() and key = "left"
        position = m.results.rowItemFocused
        if position[1] = 0
            focusField()
            return true
        end if
    else if m.keys.isInFocusChain() and key = "right"
        focusResults()
        return true
    end if
    return false
end function
sub updateResults()
    prior = m.results.rowItemFocused
    id = ""
    if m.results.content <> invalid and prior <> invalid and prior.count() = 2
        row = m.results.content.getChild(prior[0])
        if row <> invalid
            node = row.getChild(prior[1])
            if node <> invalid then id = node.id
        end if
    end if
    m.results.content = m.top.results
    if m.top.results <> invalid and id <> ""
        for r = 0 to m.top.results.getChildCount()-1
            row = m.top.results.getChild(r)
            for c = 0 to row.getChildCount()-1
                if row.getChild(c).id = id then m.results.jumpToRowItem = [r,c]
            end for
        end for
    end if
end sub
sub focusResults(position = invalid as dynamic)
    if m.results.content <> invalid and m.results.content.getChildCount() > 0
        if position <> invalid and position.count() = 2 then m.results.jumpToRowItem = position
        m.results.setFocus(true)
    else
        focusField()
    end if
end sub
