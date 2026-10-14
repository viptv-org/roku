sub init()
    m.choices = m.top.findNode("choices")
    m.choices.observeField("itemSelected","choose")
    m.actions = m.top.findNode("actions")
    m.actions.observeField("itemSelected","choiceAction")
end sub

function RestoreChoiceIndex(index as integer, count as integer) as integer
    if index < 0 or index >= count then return 0
    return index
end function

sub choose()
    index = m.choices.itemSelected
    if index < 0 or index >= m.items.count() then return
    if m.multiple
        value = Txt(m.items[index].value)
        rejected = not ChoiceHasValue(m.draft,value) and m.draft.count() >= m.maximum
        m.draft = ChoiceToggle(m.draft,value,m.maximum)
        choiceDraftChanged()
        if rejected then m.top.findNode("description").text = "Select at most "+m.maximum.toStr()+"."
        return
    end if
    m.top.visible = false
    m.top.selection = {index:index,item:m.items[index]}
end sub

sub choiceAction()
    index = m.actions.itemSelected
    if index = 0
        m.draft = []
        choiceDraftChanged()
    else if index = 1
        if m.required and m.draft.count() = 0
            m.top.findNode("description").text = "Choose at least one option."
            return
        end if
        values = []
        for each value in m.draft
            values.push(value)
        end for
        m.top.visible = false
        m.top.selection = {index:-1,item:{values:values}}
    else if index = 2
        choiceDismiss()
    end if
end sub

sub choiceDismiss()
    m.top.visible = false
    m.top.dismissed = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        choiceDismiss()
        return true
    end if
    if m.multiple
        if m.choices.hasFocus() and (key = "right" or (key = "down" and m.choices.itemFocused = m.items.count()-1))
            m.lastChoice = m.choices.itemFocused
            m.actions.jumpToItem = 1
            m.actions.setFocus(true)
            return true
        else if m.actions.hasFocus() and key = "up"
            m.choices.jumpToItem = m.lastChoice
            m.choices.setFocus(true)
            return true
        end if
    end if
    return key = "left" or key = "right"
end function
