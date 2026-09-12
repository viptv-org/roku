sub init()
    m.choices = m.top.findNode("choices")
    m.choices.observeField("itemSelected","choose")
end sub

sub render()
    model = m.top.model
    if model = invalid then return
    m.top.findNode("title").text = Txt(model.title)
    root = CreateObject("roSGNode","ContentNode")
    m.items = Bounded(model.items,2048)
    for each item in m.items
        node = root.createChild("ContentNode")
        node.title = Txt(item.name)
        node.addFields({uiWidth:792,uiHeight:52})
    end for
    count = m.items.count()
    if count < 1 then count = 1
    if count > 7 then count = 7
    panelHeight = 146 + count*62
    panelTop = int((720-panelHeight)/2)
    m.top.findNode("surface").translation = [200,panelTop]
    m.top.findNode("surface").height = panelHeight
    m.top.findNode("title").translation = [244,panelTop+32]
    m.choices.translation = [244,panelTop+94]
    m.choices.numRows = count
    m.choices.content = root
    m.top.visible = true
    index = 0
    if model.index <> invalid then index = RestoreChoiceIndex(model.index,m.items.count())
    m.choices.jumpToItem = index
    m.choices.setFocus(true)
end sub

function RestoreChoiceIndex(index as integer, count as integer) as integer
    if index < 0 or index >= count then return 0
    return index
end function

sub choose()
    index = m.choices.itemSelected
    if index < 0 or index >= m.items.count() then return
    m.top.visible = false
    m.top.selection = {index:index,item:m.items[index]}
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        m.top.visible = false
        m.top.dismissed = true
        return true
    end if
    return key = "left" or key = "right"
end function
