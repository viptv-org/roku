sub render()
    model = m.top.model
    if model = invalid then return
    m.top.findNode("title").text = Txt(model.title)
    m.items = Bounded(model.items,2048)
    m.multiple = model.multiple = true
    m.maximum = ChoiceSelectionLimit(model.maximum)
    m.required = model.required = true
    m.draft = ChoiceInitialSelection(m.items,model.selected,m.maximum)
    root = CreateObject("roSGNode","ContentNode")
    for each item in m.items
        node = root.createChild("ContentNode")
        node.title = Txt(item.name)
        fields = {uiWidth:440,uiHeight:54}
        if m.multiple
            fields.uiCheckable = true
            fields.uiIcon = ""
            if ChoiceHasValue(m.draft,Txt(item.value)) then fields.uiIcon = "check"
        end if
        node.addFields(fields)
    end for
    count = m.items.count()
    if count < 1 then count = 1
    if count > 7 then count = 7
    m.top.findNode("description").text = Txt(model.description)
    m.choices.translation = [776,130]
    if Txt(model.description) <> "" or m.multiple then m.choices.translation = [776,190]
    m.choices.numRows = count
    m.choices.content = root
    m.actions.visible = m.multiple
    if m.multiple
        actions = CreateObject("roSGNode","ContentNode")
        for each label in ["Clear","Apply","Cancel"]
            node = actions.createChild("ContentNode")
            node.title = label
            node.addFields({uiWidth:136,uiHeight:48})
        end for
        m.actions.content = actions
        choiceDraftChanged()
    end if
    m.top.visible = true
    index = 0
    if model.index <> invalid then index = RestoreChoiceIndex(model.index,m.items.count())
    m.lastChoice = index
    m.choices.jumpToItem = index
    m.choices.setFocus(true)
end sub

sub choiceDraftChanged()
    text = m.draft.count().toStr()+" selected · up to "+m.maximum.toStr()
    if m.required then text += " · choose at least one"
    m.top.findNode("description").text = text
    for i = 0 to m.items.count()-1
        icon = ""
        if ChoiceHasValue(m.draft,Txt(m.items[i].value)) then icon = "check"
        m.choices.content.getChild(i).uiIcon = icon
    end for
end sub
