' Transient renderer ownership for profile forms and parent authorization.
function rProfileContext(edit as string, target as string) as object
    return {profile_ui_version:m.profileUiVersion,profile_edit:edit,target_profile:target}
end function

function rProfileMutationCurrent(request as object) as boolean
    return request.generation = m.generation and RGet(request.context,"profile_ui_version") = m.profileUiVersion
end function

sub rRetireProfileEditor()
    old = m.profileUiVersion
    m.profileUiVersion++
    m.profileForm = invalid
    if m.inputPurpose = "createProfile" or m.inputPurpose = "renameProfile" then rClearForm()
    if m.inputPurpose = "createProfile" or m.inputPurpose = "renameProfile" then m.keyboard.text = ""
    m.keyboard.busy = false
    retained = []
    for each request in RArray(m.queue)
        retiring = request.tag = "save:profile" and RGet(request.context,"profile_ui_version") = old
        if retiring
            if m.pending[request.tag] = request.request_id then m.pending.delete(request.tag)
        else
            retained.push(request)
        end if
    end for
    m.queue = retained
    retained = []
    for each request in RArray(m.retryAuth)
        if request.tag <> "save:profile" or RGet(request.context,"profile_ui_version") <> old then retained.push(request)
    end for
    m.retryAuth = retained
    if RObject(m.afterParent)
        if m.afterParent.tag = "save:profile" and RGet(m.afterParent.context,"profile_ui_version") = old then m.afterParent = invalid
    end if
end sub

function rProfileSaveBusy() as boolean
    busy = m.pending.doesExist("save:profile")
    for each request in m.retryAuth
        if request.tag = "save:profile" and rRequestCurrent(request) then busy = true
    end for
    if busy
        message = "A profile change is still being saved. Try again."
        if m.formDialog.visible then m.formDialog.error = message else rError(message)
    end if
    return busy
end function

sub rSubmitProfileDraft()
    if not RObject(m.profileForm) then return
    if m.profileForm.version <> m.profileUiVersion then return
    if rProfileSaveBusy() then return
    m.profileForm.text = m.formDialog.text
    method = "POST"
    path = "/api/profiles"
    if m.profileForm.purpose = "renameProfile"
        method = "PATCH"
        path += "/"+REncode(m.profileForm.target)
    end if
    rSend(method,path,{name:m.profileForm.text},"save:profile",rProfileContext(m.profileForm.purpose,m.profileForm.target))
    if m.pending.doesExist("save:profile")
        m.formDialog.busy = true
        m.formDialog.error = ""
    else
        m.formDialog.error = "The connection is busy. Try again."
    end if
end sub

sub rShowProfileDraft(busy as boolean, message as string)
    if not RObject(m.profileForm) then return
    if m.profileForm.version <> m.profileUiVersion then return
    rShowForm(m.profileForm.purpose,m.profileForm.text,busy,message)
end sub

sub rProfileMutationFailure(request as object, message as string)
    if not rProfileMutationCurrent(request) then return
    if RObject(m.profileForm)
        rShowProfileDraft(false,message)
    else
        rError(message)
    end if
end sub

function rPinTag(tag as string) as boolean
    return tag = "save:unlock" or tag = "save:unlockResume"
end function

function rPinCurrent(request as object) as boolean
    if not RObject(m.pinForm) then return false
    return request.generation = m.generation and RGet(request.context,"pin_ui_version") = m.pinUiVersion
end function

sub rRetirePinEditor()
    old = m.pinUiVersion
    m.pinUiVersion++
    m.pinForm = invalid
    if m.inputPurpose = "unlock" or m.inputPurpose = "unlockResume" then rClearForm()
    if m.inputPurpose = "unlock" or m.inputPurpose = "unlockResume" then m.keyboard.text = ""
    m.keyboard.busy = false
    retained = []
    for each request in RArray(m.queue)
        retiring = rPinTag(request.tag) and RGet(request.context,"pin_ui_version") = old
        if retiring
            if m.pending[request.tag] = request.request_id then m.pending.delete(request.tag)
        else
            retained.push(request)
        end if
    end for
    m.queue = retained
    retained = []
    for each request in RArray(m.retryAuth)
        if not rPinTag(request.tag) or RGet(request.context,"pin_ui_version") <> old then retained.push(request)
    end for
    m.retryAuth = retained
end sub

sub rSubmitPinDraft()
    if not RObject(m.pinForm) then return
    if m.pinForm.version <> m.pinUiVersion then return
    tag = "save:"+m.pinForm.purpose
    if m.pending.doesExist(tag) then return
    secret = m.formDialog.text
    m.pinForm.text = secret
    rSend("POST","/api/parent/unlock",{pin:secret},tag,{pin_ui_version:m.pinUiVersion})
    if m.pending.doesExist(tag)
        m.formDialog.busy = true
        m.formDialog.error = ""
    else
        m.formDialog.error = "The connection is busy. Try again."
    end if
end sub

sub rPinFailure(request as object, message as string)
    if not rPinCurrent(request) then return
    rShowForm(m.pinForm.purpose,m.pinForm.text,false,message)
end sub

sub rFinishPinEditor()
    rRetirePinEditor()
    m.keyboard.visible = false
    m.keyboard.text = ""
    if rRestoreFormOpener() then return
    if m.drawer.visible then m.drawerRows.setFocus(true) else rFocusContent()
end sub

function rReleaseFormAuthRetries(message as string) as boolean
    handled = false
    retained = []
    for each request in m.retryAuth
        if request.tag = "save:profile" and rProfileMutationCurrent(request)
            rProfileMutationFailure(request,message)
            handled = true
        else if rPinTag(request.tag) and rPinCurrent(request)
            rPinFailure(request,message)
            handled = true
        else
            retained.push(request)
        end if
    end for
    m.retryAuth = retained
    return handled
end function

' Input overlays share a visibility guard, not a hidden-keyboard sentinel.
function rInputVisible() as boolean
    return m.keyboard.visible or m.formDialog.visible
end function

sub rClearForm()
    m.formEditing = false
    m.formDialog.visible = false
    m.formDialog.text = ""
    m.formDialog.busy = false
    m.formDialog.error = ""
end sub

sub rShowForm(purpose as string, value as string, busy as boolean, message as string)
    if m.keyboard.visible and m.inputPurpose = "search" and not m.formEditing
        m.formOpener = {generation:m.generation,keyboardFocused:m.keyboard.isInFocusChain()}
    end if
    m.inputPurpose = purpose
    m.formEditing = false
    m.keyboard.visible = false
    m.keyboard.text = ""
    m.keyboard.searchMode = false
    m.keyboard.secret = false
    m.keyboard.busy = false
    m.formDialog.purpose = purpose
    m.formDialog.text = value
    m.formDialog.busy = busy
    m.formDialog.error = message
    if busy then m.formDialog.error = ""
    m.formDialog.focusIndex = 0
    m.formDialog.visible = true
    m.top.removeChild(m.formDialog)
    m.top.appendChild(m.formDialog)
    m.formDialog.setFocus(true)
end sub

sub rFormEdit()
    if not m.formDialog.visible or m.formDialog.busy then return
    m.formEditing = true
    m.formDialog.visible = false
    m.keyboard.busy = false
    m.keyboard.error = ""
    m.keyboard.searchMode = false
    m.keyboard.prompt = "Name"
    m.keyboard.secret = false
    if m.inputPurpose = "unlock" or m.inputPurpose = "unlockResume"
        m.keyboard.prompt = "Parent PIN"
        m.keyboard.secret = true
    end if
    m.keyboard.maxLength = 2048
    m.keyboard.text = m.formDialog.text
    m.keyboard.callFunc("resetEntry")
    m.keyboard.visible = true
    m.top.removeChild(m.keyboard)
    m.top.appendChild(m.keyboard)
    m.keyboard.setFocus(true)
end sub

sub rFormEntryReturn(accept as boolean)
    if accept then m.formDialog.text = m.keyboard.text
    if accept and RObject(m.profileForm) and (m.inputPurpose = "createProfile" or m.inputPurpose = "renameProfile") then m.profileForm.text = m.formDialog.text
    if accept and RObject(m.pinForm) and (m.inputPurpose = "unlock" or m.inputPurpose = "unlockResume") then m.pinForm.text = m.formDialog.text
    m.formEditing = false
    m.keyboard.visible = false
    m.keyboard.text = ""
    m.formDialog.visible = true
    m.formDialog.focusIndex = 0
    m.formDialog.setFocus(true)
end sub

sub rFormSubmit()
    if not m.formDialog.visible or m.formDialog.busy then return
    if m.inputPurpose = "createProfile" or m.inputPurpose = "renameProfile" then rSubmitProfileDraft()
    if m.inputPurpose = "unlock" or m.inputPurpose = "unlockResume" then rSubmitPinDraft()
end sub

function rRestoreFormOpener() as boolean
    opener = m.formOpener
    m.formOpener = invalid
    if not RObject(opener) then return false
    if opener.generation <> m.generation or m.route <> "search" then return false
    rTextInput("Search","search",false,m.searchTerm)
    if not opener.keyboardFocused then rSearchResultsFocus()
    return true
end function
