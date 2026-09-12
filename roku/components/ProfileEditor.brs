sub init()
    for each id in ["form","picker","avatar","name","actions","categories","avatars","pages","page"]
        m[id] = m.top.findNode(id)
    end for
    m.top.findNode("title").font.size = 42
    m.catalog = ParseJson(ReadAsciiFile("pkg:/data/avatar-catalog.json"))
    m.actions.content = buttons(["Continue","Cancel"],240,56)
    m.pages.content = buttons(["Previous","Next"],180,40)
    names = []
    for each category in m.catalog.categories
        names.push(category.name)
    end for
    m.categories.content = buttons(names,216,44)
    m.top.findNode("pickerHint").text = m.catalog.total.toStr() + " avatars. Pick a world, then pick your character."
    m.avatar.observeField("itemSelected","pick")
    m.name.observeField("itemSelected","edit")
    m.actions.observeField("itemSelected","selected")
    m.categories.observeField("itemFocused","categoryFocused")
    m.categories.observeField("itemSelected","categorySelected")
    m.avatars.observeField("itemSelected","avatarSelected")
    m.avatars.observeField("itemFocused","avatarFocused")
    m.pages.observeField("itemSelected","pageSelected")
end sub
function buttons(titles as object,w as integer,h as integer) as object
    root = CreateObject("roSGNode","ContentNode")
    for each title in titles
        item = root.createChild("ContentNode")
        item.title = title
        item.addFields({uiWidth:w,uiHeight:h})
    end for
    return root
end function
sub open()
    m.top.visible = true
    m.top.saving = false
    m.top.message = ""
    m.picker.visible = false
    m.form.visible = true
    refresh()
    m.name.setFocus(true)
end sub
sub refresh()
    draft = m.top.draft
    titles = ["Create profile","Cancel"]
    m.top.findNode("title").text = "Add a profile"
    if draft.profile <> invalid
        m.top.findNode("title").text = "Edit profile"
        titles = ["Save","Cancel"]
        if draft.editing = true and draft.profile.is_primary <> true then titles.push("Delete profile")
    end if
    m.actions.numColumns = titles.count()
    m.actions.content = buttons(titles,240,56)
    label = draft.name
    if label = "" then label = "Enter a name"
    m.name.content = buttons([label],560,64)
    root = CreateObject("roSGNode","ContentNode")
    item = root.createChild("ContentNode")
    item.addFields({uiSize:176})
    item.hdPosterUrl = draft.avatar_url
    m.avatar.content = root
end sub
sub edit()
    if not m.top.saving then m.top.action = "name"
end sub
sub selected()
    if m.top.saving then return
    if m.actions.itemSelected = 0
        m.top.action = "submit"
    else if m.actions.itemSelected = 2
        m.top.action = "delete"
    else
        m.top.action = "cancel"
    end if
end sub
sub pick()
    if m.top.saving then return
    m.form.visible = false
    m.picker.visible = true
    m.category = 0
    for i = 0 to m.catalog.categories.count()-1
        if m.catalog.categories[i].style = m.top.draft.avatar_style then m.category = i
    end for
    m.pageIndex = 0
    m.categories.jumpToItem = m.category
    loadPage()
    m.categories.setFocus(true)
end sub
sub categoryFocused()
    m.category = m.categories.itemFocused
    m.pageIndex = 0
    if m.picker.visible then loadPage()
end sub
sub categorySelected()
    m.avatars.setFocus(true)
end sub
sub loadPage()
    root = CreateObject("roSGNode","ContentNode")
    category = m.catalog.categories[m.category]
    style = category.style
    total = 48
    if category.items <> invalid then total = category.items.count()
    m.pageCount = int((total+17)/18)
    m.pages.visible = m.pageCount > 1
    first = m.pageIndex * 18 + 1
    last = first + 17
    if last > total then last = total
    for choice = first to last
        node = root.createChild("ContentNode")
        node.hdPosterUrl = "pkg:/images/avatar-catalog/" + style + "-" + choice.toStr() + ".png"
        if category.items <> invalid then node.hdPosterUrl = category.items[choice-1].local
    end for
    m.avatars.content = root
    m.avatars.jumpToItem = 0
    avatarFocused()
    m.page.text = m.catalog.categories[m.category].name + "  ·  " + (m.pageIndex+1).toStr() + " / " + m.pageCount.toStr()
end sub
sub pageSelected()
    if m.pages.itemSelected = 0
        m.pageIndex = (m.pageIndex+m.pageCount-1) mod m.pageCount
    else
        m.pageIndex = (m.pageIndex+1) mod m.pageCount
    end if
    loadPage()
    m.avatars.setFocus(true)
end sub
sub avatarSelected()
    draft = m.top.draft
    draft.avatar_style = m.catalog.categories[m.category].style
    draft.avatar_choice = m.pageIndex*18 + m.avatars.itemSelected + 1
    draft.avatar_url = "pkg:/images/avatar-catalog/" + draft.avatar_style + "-" + draft.avatar_choice.toStr() + ".png"
    category = m.catalog.categories[m.category]
    if category.items <> invalid then draft.avatar_url = category.items[draft.avatar_choice-1].local
    m.top.draft = draft
    m.picker.visible = false
    m.form.visible = true
    refresh()
    m.avatar.setFocus(true)
end sub
function onKeyEvent(key as string,press as boolean) as boolean
    if not press then return false
    if m.top.saving then return true
    if m.picker.visible
        if key = "back"
            m.picker.visible = false
            m.form.visible = true
            m.avatar.setFocus(true)
        else if m.categories.hasFocus() and key = "right"
            m.avatars.setFocus(true)
        else if m.avatars.hasFocus() and key = "left"
            m.categories.setFocus(true)
        else if m.avatars.hasFocus() and key = "down" and m.pages.visible
            m.pages.setFocus(true)
        else if m.pages.hasFocus() and key = "up"
            m.avatars.setFocus(true)
        else
            return false
        end if
    else
        if key = "back"
            m.top.action = "cancel"
        else if m.name.hasFocus() and key = "left"
            m.avatar.setFocus(true)
        else if m.avatar.hasFocus() and key = "right"
            m.name.setFocus(true)
        else if (m.name.hasFocus() or m.avatar.hasFocus()) and key = "down"
            m.actions.setFocus(true)
        else if m.actions.hasFocus() and key = "up"
            m.name.setFocus(true)
        else
            return false
        end if
    end if
    return true
end function

sub avatarFocused()
    label = m.top.findNode("pickedName")
    label.text = ""
    if m.category = invalid then return
    category = m.catalog.categories[m.category]
    if category.items = invalid then return
    index = m.pageIndex*18 + m.avatars.itemFocused
    if index >= 0 and index < category.items.count() then label.text = category.items[index].name
end sub
