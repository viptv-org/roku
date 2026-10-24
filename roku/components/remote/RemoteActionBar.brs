sub init()
    m.top.focusable = true
    m.items = m.top.findNode("items")
    m.top.observeField("focusedChild","paint")
end sub
sub render()
    m.items.removeChildrenIndex(m.items.getChildCount(),0)
    if m.top.content = invalid then return
    x = 0
    for each item in m.top.content.getChildren(-1,0)
        item.uiWidth = RGet(item.wire,"width",item.uiWidth)
        tile = m.items.createChild("RemoteItem")
        tile.translation = [x,0]
        tile.itemContent = item
        x += item.uiWidth+20
    end for
    if m.top.itemFocused >= m.items.getChildCount() then m.top.itemFocused = 0
    paint()
end sub
sub paint()
    if m.items = invalid then return
    for i = 0 to m.items.getChildCount()-1
        tile = m.items.getChild(i)
        tile.listHasFocus = m.top.isInFocusChain()
        if i = m.top.itemFocused then tile.focusPercent = 1 else tile.focusPercent = 0
    end for
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
