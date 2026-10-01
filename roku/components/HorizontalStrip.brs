sub init()
    m.views = []
    m.scroll = 0
    m.items = m.top.findNode("items")
end sub
sub contentChanged()
    if m.top.content = invalid then return
    index = m.top.itemFocused
    if index >= m.top.content.getChildCount() then index = 0
    m.top.itemFocused = index
    render()
end sub
sub jump()
    if m.top.content = invalid then return
    index = m.top.jumpToItem
    if index < 0 then index = 0
    if index >= m.top.content.getChildCount() then index = m.top.content.getChildCount()-1
    if index < 0 then index = 0
    m.top.itemFocused = index
    render()
end sub
sub render()
    if m.items = invalid or m.top.content = invalid then return
    count = m.top.content.getChildCount()
    width = m.top.itemSize[0]
    height = m.top.itemSize[1]
    pitch = width+m.top.itemSpacing[0]
    viewport = m.top.viewportWidth
    index = m.top.itemFocused
    if index*pitch < m.scroll then m.scroll = index*pitch
    if index*pitch+width > m.scroll+viewport then m.scroll = index*pitch+width-viewport
    maxScroll = count*pitch-m.top.itemSpacing[0]-viewport
    if m.scroll > maxScroll then m.scroll = maxScroll
    if m.scroll < 0 then m.scroll = 0
    m.top.clippingRect = [0,0,viewport,height]
    first = int(m.scroll/pitch)
    for slot = 0 to 5
        if slot >= m.views.count()
            card = m.items.createChild(m.top.itemComponentName)
            m.views.push(card)
        end if
        card = m.views[slot]
        at = first+slot
        card.visible = at < count
        if card.visible
            item = m.top.content.getChild(at)
            different = card.itemContent = invalid
            if not different then different = not card.itemContent.isSameNode(item)
            if different then card.itemContent = item
            card.translation = [at*pitch-m.scroll,0]
            card.gridHasFocus = m.top.active
            percent = 0.0
            if at = index then percent = 1.0
            card.focusPercent = percent
        end if
    end for
end sub
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.top.content = invalid then return false
    index = m.top.itemFocused
    count = m.top.content.getChildCount()
    if key = "left" or key = "right"
        if key = "left" and index > 0 then index--
        if key = "right" and index < count-1 then index++
        m.top.itemFocused = index
        m.top.active = true
        render()
        return true
    end if
    if key = "OK"
        if count > 0 then m.top.itemSelected = index
        return true
    end if
    return false
end function
