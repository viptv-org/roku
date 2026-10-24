sub rHistoryClearSelected()
    if m.historyEntries.count() > 0 then rRun({action:"confirmClearHistory"})
end sub

sub rHistory(data as object)
    selected = ""
    hadContent = m.rows.visible and m.rows.content <> invalid
    if hadContent
        node = m.rows.content.getChild(m.rows.itemFocused)
        if node <> invalid and RCard(RGet(node.wire,"card")) then selected = RIdentityKey(node.wire.card)
    end if
    entries = RArray(data)
    m.historyEntries.append(entries)
    m.historyMore = entries.count() = 100
    m.historyOffset += entries.count()
    while m.historyEntries.count() > 300
        m.historyEntries.shift()
    end while
    values = []
    for each entry in m.historyEntries
        ' Status text and artwork roles are projected by the current producer.
        values.push({title:entry.card.title,subtitle:RText(entry.card.subtitle),action:"detail",card:entry.card,history:true,landscape:RText(entry.card.landscape)})
    end for
    m.rows.translation = [92,336]
    m.rows.itemSize = [1736,156]
    m.rows.itemSpacing = [0,4]
    m.rows.numRows = 5
    m.top.findNode("rowClip").clippingRect = [88,340,1744,740]
    m.rows.content = rContent(values,1728,148)
    m.rows.visible = values.count() > 0
    m.top.findNode("historyExplanation").visible = true
    m.historyClear.content = rContent([{title:"Clear history",action:"confirmClearHistory"}],260,64)
    m.historyClear.visible = values.count() > 0
    m.top.findNode("historyEmpty").visible = values.count() = 0
    if values.count() = 0
        rShowActions([{title:"Browse Home",action:"home",width:280}])
        m.actions.translation = [96,560]
        m.actions.setFocus(true)
    else
        for i = 0 to values.count()-1
            if RIdentityKey(values[i].card) = selected then m.rows.jumpToItem = i
        end for
        if not hadContent then m.rows.setFocus(true)
    end if
end sub
