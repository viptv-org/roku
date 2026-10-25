sub init()
    m.top.focusable = true
    m.barWidth = 0
    m.items = m.top.findNode("items")
    m.top.observeField("focusedChild","paint")
end sub
sub render()
    m.items.removeChildrenIndex(m.items.getChildCount(),0)
    if m.top.content = invalid then return
    x = 0
    for each item in m.top.content.getChildren(-1,0)
        ' Content nodes built outside rContent may not carry uiWidth; a missing
        ' width must not abort the whole bar with a type mismatch.
        w = 0
        if item.hasField("uiWidth") and GetInterface(item.uiWidth,"ifInt") <> invalid then w = item.uiWidth
        if GetInterface(item.uiWidth,"ifFloat") <> invalid then w = item.uiWidth
        value = 0
        if RObject(item.wire) then value = RGet(item.wire,"width",w)
        if GetInterface(value,"ifInt") <> invalid then w = value
        if GetInterface(value,"ifFloat") <> invalid then w = value
        if item.hasField("uiWidth") then item.uiWidth = w
        tile = m.items.createChild("RemoteItem")
        tile.translation = [x,0]
        tile.itemContent = item
        x += w+20
    end for
    m.barWidth = x-20
    if m.top.align = "center" and m.top.containerWidth > 0 and m.items.getChildCount() > 0
        total = m.barWidth
        offset = int((m.top.containerWidth-total)/2)
        if offset < 0 then offset = 0
        for each tile in m.items.getChildren(-1,0)
            tile.translation = [tile.translation[0]+offset,0]
        end for
    end if
    if m.top.itemFocused >= m.items.getChildCount() then m.top.itemFocused = 0
    paint()
end sub
sub paint()
    if m.items = invalid then return
    barFocused = m.top.isInFocusChain()
    for i = 0 to m.items.getChildCount()-1
        tile = m.items.getChild(i)
        tile.listHasFocus = barFocused
        ' focusPercent is the single source of truth for RemoteItem focus.
        if barFocused and i = m.top.itemFocused then tile.focusPercent = 1 else tile.focusPercent = 0
    end for
    if m.top.scroll and m.top.containerWidth > 0 then rWindow()
end sub

' Long filter rows keep the focused chip in the first slot and move the row.
sub rWindow()
    count = m.items.getChildCount()
    if count = 0 then
        m.items.translation = [0,0]
        return
    end if
    index = m.top.itemFocused
    if index < 0 or index > count-1 then index = 0
    tile = m.items.getChild(index)
    if tile = invalid then return
    ' A Group has no width field; the laid-out bar width is tracked in render().
    total = m.barWidth
    offset = -tile.translation[0]
    if offset > 0 then offset = 0
    limit = m.top.containerWidth-total
    if limit > 0 then limit = 0
    if offset < limit then offset = limit
    m.items.translation = [offset,0]
end sub
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "left"
        if m.top.itemFocused > 0 then m.top.itemFocused--
    else if key = "right"
        if m.top.itemFocused < m.items.getChildCount()-1 then m.top.itemFocused++
    else if key = "OK"
        m.top.itemSelected = m.top.itemFocused
    else
        return false
    end if
    return true
end function
