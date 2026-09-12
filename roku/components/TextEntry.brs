sub init()
    m.top.findNode("title").font.size = 42
    m.keys = m.top.findNode("keys")
    m.keys.textEditBox.visible = false
    m.keys.observeField("text","updateValue")
    m.actions = m.top.findNode("actions")
    root = CreateObject("roSGNode","ContentNode")
    for each title in ["Done","Cancel"]
        node = root.createChild("ContentNode")
        node.title = title
        node.addFields({uiWidth:240,uiHeight:56})
    end for
    m.actions.content = root
    m.actions.observeField("itemSelected","selected")
end sub
sub open()
    m.top.findNode("title").text = m.top.heading
    m.keys.textEditBox.maxTextLength = m.top.limit
    m.keys.textEditBox.clearOnDownKey = false
    m.keys.text = m.top.value
    updateValue()
    m.top.visible = true
    m.keys.setFocus(true)
end sub
sub updateValue()
    value = m.keys.text
    if m.top.secret then value = string(len(value),"*")
    m.top.findNode("valueLabel").text = value
end sub
sub selected()
    finishEntry(m.actions.itemSelected = 0)
end sub
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if KeyboardMobileInput(m.keys,key) then return true
    if key = "enter"
        finishEntry(true)
        return true
    end if
    if key = "back"
        finishEntry(false)
        return true
    else if key = "down" and m.keys.isInFocusChain()
        m.actions.setFocus(true)
        return true
    else if key = "up" and m.actions.hasFocus()
        m.keys.setFocus(true)
        return true
    end if
    return false
end function

sub finishEntry(accepted as boolean)
    value = m.keys.text
    if not accepted then value = ""
    if m.top.secret
        m.keys.text = ""
        m.top.value = ""
        m.top.findNode("valueLabel").text = ""
    end if
    m.top.result = {accepted:accepted,text:value}
end sub

sub clear()
    m.keys.text = ""
    m.top.value = ""
    m.top.findNode("valueLabel").text = ""
    m.top.result = invalid
end sub
