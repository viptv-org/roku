sub accountUseProfiles(profiles as dynamic)
    values = AccountProfileRows(profiles,false)
    primary = ""
    for each value in values
        id = Txt(value.id)
        if id <> "" and (primary = "" or val(id) < val(primary)) then primary = id
    end for
    for each value in values
        ' Legacy servers omit this flag; explicit server policy takes precedence.
        if Txt(value.id) <> "" and GetInterface(value.is_primary,"ifBoolean") = invalid then value.is_primary = Txt(value.id) = primary
    end for
    remembered = Txt(m.config.last_profile_id)
    if remembered <> "" and m.switchingProfile <> true and m.managingProfiles <> true
        for each item in values
            if Txt(item.id) = remembered
                if item.presentation_complete = true
                    accountChoose(item)
                else if m.canCreateProfile = true
                    accountStartProfileSetup(item)
                else
                    accountShowProfileGrid(values)
                    m.status.text = "Finish profile setup on your phone at " + Txt(m.config.base,"https://viptv.syek.tech")
                end if
                return
            end if
        end for
        m.config.last_profile_id = ""
        request("CONFIG_SAVE","",m.config,"sideconfig")
    end if
    m.switchingProfile = false
    realCount = 0
    imported = invalid
    for each item in values
        if Txt(item.id) <> ""
            realCount++
            if item.presentation_complete <> true and imported = invalid then imported = item
        end if
    end for
    if m.profileSetupCancelled = true
        m.profileSetupCancelled = false
        accountShowProfileGrid(values)
    else if realCount = 0 and m.canCreateProfile = true
        accountStartProfileSetup(invalid)
    else if realCount = 1 and imported <> invalid and m.canCreateProfile = true
        accountStartProfileSetup(imported)
    else
        accountShowProfileGrid(values)
    end if
end sub

sub accountShowProfileGrid(values as object)
    m.accountProfiles = values
    m.profilePage = 0
    if Txt(m.profileFocusId) <> ""
        for i = 0 to values.count()-1
            if Txt(values[i].id) = m.profileFocusId then m.profilePage = int(i / 5)
        end for
    end if
    accountRenderProfilePage()
end sub

sub accountRenderProfilePage()
    page = AccountProfilePage(m.accountProfiles,m.profilePage)
    m.profilePage = page.index
    values = page.items
    title = "Who's watching?"
    if m.managingProfiles = true then title = "Manage profiles"
    rows(title,values,"profiles","")
    m.heading.translation = [100,146]
    m.heading.width = 1080
    m.heading.horizAlign = "center"
    m.heading.font.size = 44
    if m.profileGrid = invalid then return
    content = CreateObject("roSGNode","ContentNode")
    for each value in values
        child = content.createChild("ContentNode")
        child.addFields(value)
        child.addFields({uiOwnerFocused:false})
    end for
    columns = values.count()
    if columns < 1 then columns = 1
    gridWidth = columns * 178 + (columns - 1) * 34
    m.profileGrid.numColumns = columns
    m.profileGrid.translation = [int((1280 - gridWidth) / 2),252]
    m.profileGrid.content = content
    m.profileGrid.visible = values.count() > 0
    m.profileGrid.jumpToItem = 0
    if Txt(m.profileFocusId) <> ""
        for i = 0 to values.count()-1
            if Txt(values[i].id) = m.profileFocusId then m.profileGrid.jumpToItem = i
        end for
    end if
    m.profileButtons = AccountProfileButtons(m.accountProfiles.count(),m.canCreateProfile = true,m.managingProfiles = true)
    accountFillProfileButtons(m.profileActions,m.profileButtons,240,56,530)
    accountFillProfileButtons(m.profilePages,[{name:"Previous",action:"previous"},{name:"Next",action:"next"}],180,40,612)
    m.profilePages.visible = page.count > 1
    m.profilePageLabel.visible = page.count > 1
    m.profilePageLabel.text = (page.index+1).toStr() + " / " + page.count.toStr()
    if values.count() > 0
        m.profileGrid.setFocus(true)
    else
        m.profileActions.setFocus(true)
    end if
    uiFocusChanged()
end sub

sub accountFillProfileButtons(grid as object,items as object,width as integer,height as integer,y as integer)
    content = CreateObject("roSGNode","ContentNode")
    for each item in items
        child = content.createChild("ContentNode")
        child.title = item.name
        child.addFields({uiWidth:width,uiHeight:height,uiOwnerFocused:false})
    end for
    count = items.count()
    grid.content = content
    grid.visible = count > 0
    if count = 0 then return
    grid.numColumns = count
    grid.translation = [int((1280-count*width-(count-1)*16)/2),y]
end sub

sub accountProfileButtonSelected()
    index = m.profileActions.itemSelected
    if index < 0 or index >= m.profileButtons.count() then return
    accountProfileAction(m.profileButtons[index])
end sub

sub accountProfilePageSelected()
    if m.profilePages.itemSelected = 0
        m.profilePage--
    else
        m.profilePage++
    end if
    page = AccountProfilePage(m.accountProfiles,m.profilePage)
    m.profilePage = page.index
    m.profileFocusId = ""
    if page.items.count() > 0 then m.profileFocusId = Txt(page.items[0].id)
    accountRenderProfilePage()
end sub

function accountProfileKey(key as string) as boolean
    if m.mode <> "profiles" or m.profileGrid = invalid then return false
    if key = "down" and m.profileGrid.hasFocus()
        index = m.profileGrid.itemFocused
        if index <> invalid and m.items <> invalid
            if index >= 0 and index < m.items.count() then m.profileFocusId = Txt(m.items[index].id)
        end if
    end if
    if key = "down" and m.profileGrid.hasFocus() and m.profileActions.visible
        m.profileActions.setFocus(true)
    else if key = "down" and m.profileGrid.hasFocus() and m.profilePages.visible
        m.profilePages.setFocus(true)
    else if key = "up" and m.profileActions.hasFocus() and m.profileGrid.visible
        m.profileGrid.setFocus(true)
    else if key = "down" and m.profileActions.hasFocus() and m.profilePages.visible
        m.profilePages.setFocus(true)
    else if key = "up" and m.profilePages.hasFocus()
        if m.profileActions.visible
            m.profileActions.setFocus(true)
        else
            m.profileGrid.setFocus(true)
        end if
    else
        return false
    end if
    uiFocusChanged()
    return true
end function

sub accountStartProfileSetup(profile as dynamic)
    if m.canCreateProfile <> true
        m.status.text = "Manage profiles on your phone at " + Txt(m.config.base,"https://viptv.syek.tech")
        return
    end if
    cancelBrowse()
    for each node in [m.profileGrid,m.profileActions,m.profilePages,m.profilePageLabel]
        if node <> invalid then node.visible = false
    end for
    m.mode = "profileeditor"
    m.profileDraft = {editing:m.managingProfiles = true,profile:profile,name:"",avatar_style:"disney",avatar_choice:1,avatar_url:"pkg:/images/avatar-characters/disney-1.png"}
    if profile <> invalid
        m.profileDraft.name = Txt(profile.name)
        m.profileDraft.avatar_style = AccountAvatarStyle(profile.avatar_style)
        m.profileDraft.avatar_choice = profile.avatar_choice
        m.profileDraft.avatar_url = AccountAvatarUrl(profile.avatar_url)
    end if
    accountEndLoading()
    uiBusy(false)
    m.profileEditor.draft = m.profileDraft
    m.profileEditor.callFunc("open")
end sub

sub accountSubmitProfileName(name as string)
    if m.profileDraft = invalid then return
    m.profileDraft.name = left(name.trim(),80)
    m.profileEditor.draft = m.profileDraft
    m.profileEditor.callFunc("refresh")
end sub

sub accountEditorAction()
    action = m.profileEditor.action
    m.profileDraft = m.profileEditor.draft
    if action = "name"
        keyboard("accountprofilename","Name this profile",m.profileDraft.name)
    else if action = "cancel"
        m.profileEditor.visible = false
        m.profileDraft = invalid
        m.profileSetupCancelled = true
        accountOpenProfiles()
    else if action = "delete"
        accountConfirmProfileDelete()
    else if action = "submit"
        if m.profileDraft.name.trim() = ""
            m.profileEditor.message = "Enter a name to continue."
            return
        end if
        accountFinishProfileSetup(m.profileDraft.avatar_style)
    end if
end sub

sub accountFinishProfileSetup(styleValue as dynamic)
    if m.profileDraft = invalid or m.authBusy = true then return
    style = AccountAvatarStyle(styleValue)
    if style = "" then return
    body = {name:m.profileDraft.name.trim(),avatar_style:style}
    if m.profileDraft.avatar_choice <> invalid then body.avatar_choice = m.profileDraft.avatar_choice
    m.authBusy = true
    m.profileEditor.saving = true
    m.profileEditor.message = "Saving profile…"
    profile = m.profileDraft.profile
    if profile = invalid
        request("POST","/api/profiles",body,"auth:newprofile")
    else
        body.setup_complete = true
        request("PATCH","/api/profiles/" + Enc(Txt(profile.id)),body,"auth:setupprofile")
    end if
end sub

sub accountProfileAction(item as object)
    if Txt(item.action) = "manageprofiles"
        accountManageProfiles()
    else if Txt(item.action) = "profilesdone"
        m.managingProfiles = false
        accountOpenProfiles()
    else if Txt(item.action) = "newprofile"
        accountStartProfileSetup(invalid)
    else if Txt(item.action) = "accountavatar"
        accountFinishProfileSetup(item.avatar_style)
    else if m.managingProfiles = true or item.presentation_complete <> true
        m.profileFocusId = Txt(item.id)
        accountStartProfileSetup(item)
    else
        accountChoose(item)
    end if
end sub

sub accountChoose(item as object)
    if m.authBusy = true
        m.status.text = "Finishing sign-in. Try that profile again shortly."
        return
    end if
    accountReset()
    m.pendingProfile = item
    m.authBusy = true
    m.status.text = "Opening " + Txt(item.name,"profile") + "…"
    profileId = item.id
    idText = Txt(item.id)
    if CreateObject("roRegex","^[0-9]{1,9}$","").isMatch(idText) then profileId = int(val(idText))
    request("POST","/api/auth/profile",{profile_id:profileId},"auth:profile")
end sub

' Opening the chooser is not signing out, nor clearing the remembered profile.
sub accountOpenProfiles()
    m.switchingProfile = true
    cancelBrowse()
    rows("Who's watching?",[],"profiles","")
    if Txt(m.config.refresh_token) = ""
        accountConnect()
        return
    end if
    request("GET","/api/profiles",invalid,"profiles")
    m.status.text = "Loading profiles…"
end sub

function accountProfileBack() as boolean
    if m.mode <> "profiles" then return false
    if m.parentUnlockPending = true
        m.pendingProfile = invalid
        m.parentUnlockPending = false
        m.authBusy = false
        m.accountEpoch++
    end if
    if m.managingProfiles = true
        m.managingProfiles = false
        accountOpenProfiles()
        return true
    end if
    m.switchingProfile = false
    cancelBrowse()
    if m.profile <> ""
        m.views = []
        home()
    end if
    return true
end function

' PIN is transient: no registry/config writes and no background polling.
sub accountSubmitParentPin(result as object)
    if not result.accepted
        if m.parentAction = "profilemutation"
            m.parentAction = ""
            m.profileMutation = invalid
            m.authBusy = false
            m.profileEditor.callFunc("open")
            return
        end if
        if m.parentAction = "logout"
            m.parentAction = ""
            m.authBusy = false
            showSettings()
            return
        end if
        m.pendingProfile = invalid
        m.authBusy = false
        accountOpenProfiles()
        return
    end if
    pin = Txt(result.text)
    result.text = ""
    if not CreateObject("roRegex","^[0-9]{4,8}$","").isMatch(pin)
        keyboard("parentpin","Enter a 4–8 digit parent PIN","")
        return
    end if
    m.authBusy = true
    m.parentUnlockPending = true
    m.status.text = "Unlocking… Back cancels."
    if m.parentAction = "logout"
        showSettings()
    else if m.profileGrid <> invalid
        m.profileGrid.setFocus(true)
    end if
    request("POST","/api/parent/unlock",{pin:pin},"auth:parentunlock")
end sub

sub accountSignOut()
    m.authBusy = true
    m.status.text = "Signing out…"
    request("POST","/api/auth/logout",{},"auth:logout")
end sub

sub accountManageProfiles()
    m.profileFocusId = Txt(m.profile)
    m.managingProfiles = true
    accountOpenProfiles()
end sub

sub accountConfirmProfileDelete()
    if m.profileDraft = invalid then return
    profile = m.profileDraft.profile
    if profile = invalid then return
    if profile.is_primary = true then return
    dialog = CreateObject("roSGNode","Dialog")
    dialog.title = "Delete " + Txt(profile.name) + "?"
    dialog.message = "This removes this profile's watch history, favorites and preferences. Other profiles are kept."
    dialog.buttons = ["Cancel","Delete profile"]
    dialog.observeField("buttonSelected","accountDeleteConfirmed")
    dialog.observeField("wasClosed","accountDeleteClosed")
    m.top.dialog = dialog
end sub

sub accountDeleteConfirmed(event = invalid as dynamic)
    if m.top.dialog = invalid then return
    if event <> invalid
        if not event.getRoSGNode().isSameNode(m.top.dialog) then return
    end if
    confirmed = m.top.dialog.buttonSelected = 1
    m.top.dialog.close = true
    if not confirmed then return
    if m.profileDraft = invalid then return
    profile = m.profileDraft.profile
    if profile = invalid then return
    if profile.is_primary = true then return
    m.authBusy = true
    m.profileEditor.saving = true
    m.profileEditor.message = "Deleting profile…"
    request("DELETE","/api/profiles/" + Enc(Txt(profile.id)),invalid,"auth:deleteprofile")
end sub

sub accountDeleteClosed()
    if m.profileEditor.visible and m.authBusy <> true then m.profileEditor.callFunc("open")
end sub
