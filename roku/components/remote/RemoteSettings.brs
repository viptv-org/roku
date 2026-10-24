sub rSettings()
    rSettingsSection("Account")
    m.settingsNav.setFocus(true)
end sub

sub rSettingsNavSelected()
    node = m.settingsNav.content.getChild(m.settingsNav.itemSelected)
    if node <> invalid then rRun(node.wire)
end sub

sub rSettingsSection(section as string)
    rReset("settings")
    m.section = section
    m.settingsSidebar.visible = true
    m.message.translation = [640,940]
    m.message.width = 1184
    m.navigation.visible = false
    sections = [{title:"Account",action:"section",section:"Account"},{title:"Profiles",action:"profiles"},{title:"Playback",action:"section",section:"Playback"},{title:"Subtitles & audio",action:"section",section:"Subtitles & audio"},{title:"Add-ons",action:"section",section:"Add-ons"},{title:"Source integrations",action:"section",section:"Source integrations"},{title:"Parental controls",action:"section",section:"Parental controls"},{title:"About",action:"section",section:"About"}]
    selectedIndex = 0
    sectionIndex = 0
    for each item in sections
        item.sidebar = true
        item.ring = false
        item.selected = item.section = section
        if item.selected then selectedIndex = sectionIndex
        sectionIndex++
        icons = {Account:"profile",Profiles:"remote-users",Playback:"remote-play","Subtitles & audio":"remote-captions","Add-ons":"addons","Source integrations":"remote-server","Parental controls":"remote-lock",About:"info"}
        item.icon = icons[item.title]
    end for
    m.settingsNav.content = rContent(sections,440,72)
    m.settingsNav.jumpToItem = selectedIndex
    m.heading.text = ""
    m.top.findNode("settingsHeading").text = section
    m.top.findNode("settingsHeading").visible = true
    if RText(m.navigation.profileName) <> "" then m.top.findNode("settingsExplanation").text = "These apply to "+m.navigation.profileName+"’s profile."
    m.heading.translation = [640,93]
    m.heading.width = 1184
    m.heading.font.size = 40
    m.rows.translation = [640,220]
    m.rows.itemSize = [1184,96]
    m.rows.itemSpacing = [0,12]
    m.skeleton.visible = true
    if section = "Playback" or section = "Subtitles & audio"
        rSend("GET",rProfilePath("/preferences"),invalid,"settings:preferences")
    else if section = "Source integrations"
        rSend("GET",rProfilePath("/source-integrations"),invalid,"settings:sources")
    else if section = "Add-ons"
        m.integrations = invalid
        m.addonStates = invalid
        rSend("GET",rProfilePath("/integrations"),invalid,"settings:integrations")
        rSend("GET",rProfilePath("/addon-activation"),invalid,"settings:addonStates")
    else if section = "Parental controls"
        rSend("GET","/api/parent/status",invalid,"settings:parent")
    else if section = "Account"
        rShowRows([{title:"Sign out",action:"confirmSignout"},{title:"Simkl",action:"simkl"}])
    else if section = "About"
        m.message.translation = [640,220]
        m.skeleton.visible = false
        m.message.text = "VIPTV for Roku · Server-connected viewing"+chr(10)+m.config.base
    end if
    rFocusContent()
end sub

sub rSettingsResponse(tag as string, data as dynamic, request as object)
    if tag = "settings:membership"
        m.membership = data
        if m.actions.content <> invalid
            values = []
            for each node in m.actions.content.getChildren(-1,0)
                value = node.wire
                if value.action = "saveTitle"
                    if rIsSaved(value.card) then value.icon = "check" else value.icon = "plus"
                end if
                values.push(value)
            end for
            rShowActions(values)
        end if
        return
    else if tag = "settings:preferences"
        m.preferences = data
        values = []
        group = "playback"
        if m.section = "Subtitles & audio" then group = "subtitles"
        for each control in RArray(data.controls)
            if control.group = group
                label = ""
                for each choice in RArray(control.choices)
                    if REqual(choice.value,data.preferences[control.id]) then label = choice.label
                end for
                current = data.preferences[control.id]
                toggle = GetInterface(current,"ifBoolean") <> invalid and RArray(control.choices).count() = 2
                for each choice in RArray(control.choices)
                    if GetInterface(choice.value,"ifBoolean") = invalid then toggle = false
                end for
                values.push({title:control.label,subtitle:RText(control.description),setting:true,settingValue:label,checked:current,toggle:toggle,action:"preference",field:control.id,choices:control.choices})
            end if
        end for
        rShowRows(values)
        if values.count() = 0 then rError("This server needs an update to provide preference controls.")
    else if tag = "settings:sources"
        m.sourceSchemas = data
        values = []
        for each schema in RArray(data.schemas)
            if schema.runtime_enabled = true and schema.state <> "Unavailable"
                values.push({title:schema.name,subtitle:schema.state,action:"configureSource",schema:schema})
            end if
        end for
        rShowRows(values)
        if values.count() = 0 then m.message.text = "No source integrations are available on this server."
    else if tag = "settings:integrations"
        m.integrations = data
        rAddonRows()
    else if tag = "settings:addonStates"
        m.addonStates = data
        rAddonRows()
    else if tag = "settings:parent"
        m.parentAccess = data
        values = []
        if data.pin_configured = true and data.unlocked <> true then values.push({title:"Unlock parental controls",action:"unlock"})
        rShowRows(values)
        m.message.text = ""
        m.message.width = 1184
        m.message.translation = [640,940]
        if data.pin_configured <> true
            m.message.translation = [640,220]
            m.message.text = "Set up your parent PIN from your account at "+m.config.base
        else if data.unlocked = true
            m.message.translation = [640,220]
            m.message.text = "Parent PIN unlocked"
        end if
    else if tag = "settings:simkl"
        if data.linked = true
            rOpenDrawer("Simkl",[{title:"Connected",subtitle:"Your viewing history is synchronized",action:"close"},{title:"Disconnect Simkl",action:"confirmUnlink"}],"simkl")
        else
            rOpenDrawer("Simkl",[],"simkl")
            m.drawerMessage.text = "Connect Simkl from your account at "+m.config.base
        end if
    end if
    if not m.drawer.visible then rFocusContent()
end sub

sub rSettingsAction(value as object)
    action = RText(value.action)
    if (action = "preference" or action = "savePreference") and rPreferenceBusy()
        if m.drawer.visible then m.drawerMessage.text = "Saving…" else m.message.text = "Saving…"
        return
    end if
    if action = "section"
        rSettingsSection(value.section)
    else if action = "preference"
        if RGet(value,"toggle",false)
            for each choice in value.choices
                if choice.value <> value.checked
                    rSettingsAction({action:"savePreference",field:value.field,value:choice.value})
                    return
                end if
            end for
        end if
        choices = []
        for each choice in value.choices
            choices.push({title:choice.label,action:"savePreference",field:value.field,value:choice.value})
        end for
        rOpenDrawer(value.title,choices,"preference")
    else if action = "savePreference"
        p = RCopy(m.preferences.preferences)
        p[value.field] = value.value
        rSend("PUT",rProfilePath("/preferences"),{revision:m.preferences.revision,preferences:p},"save:preferences")
        if m.pending.doesExist("save:preferences")
            if m.drawer.visible then m.drawerMessage.text = "Saving…" else m.message.text = "Saving…"
        end if
    else if action = "createProfile"
        rTextInput("Profile name","createProfile",false,"")
    else if action = "manageProfiles"
        values = []
        for each profile in RArray(m.management.profiles)
            values.push({title:profile.name,action:"editProfile",profile:profile})
        end for
        rOpenDrawer("Manage profiles",values,"profiles")
    else if action = "editProfile"
        rRetireProfileEditor()
        m.editProfile = value.profile
        values = []
        caps = m.management.capabilities
        if RGet(caps.rename,"availability") = "Available" then values.push({title:"Name",subtitle:value.profile.name,action:"renameProfile"})
        if RGet(caps.avatar,"availability") = "Available" then values.push({title:"Avatar",action:"avatar"})
        if RGet(caps.delete,"availability") = "Available" and value.profile.can_delete = true then values.push({title:"Delete profile",action:"confirmDeleteProfile"})
        rOpenDrawer(value.profile.name,values,"editProfile")
    else if action = "renameProfile"
        rTextInput("Profile name","renameProfile",false,m.editProfile.name)
    else if action = "avatar"
        values = []
        for each id in RArray(m.management.avatar_ids)
            values.push({title:id,action:"saveAvatar",value:id})
        end for
        rOpenDrawer("Choose avatar",values,"avatar")
    else if action = "saveAvatar"
        if rProfileSaveBusy() then return
        rSend("PATCH","/api/profiles/"+REncode(m.editProfile.id),{avatar_id:value.value},"save:profile",rProfileContext("avatar",m.editProfile.id))
        if m.pending.doesExist("save:profile") then m.drawerMessage.text = "Saving…"
    else if action = "confirmDeleteProfile"
        rOpenDrawer("Delete "+m.editProfile.name+"?",[{title:"Cancel",action:"close"},{title:"Delete profile",action:"deleteProfile"}],"profileConfirm")
    else if action = "deleteProfile"
        if rProfileSaveBusy() then return
        rSend("DELETE","/api/profiles/"+REncode(m.editProfile.id),invalid,"save:profile",rProfileContext("delete",m.editProfile.id))
        if m.pending.doesExist("save:profile") then m.drawerMessage.text = "Saving…"
    else if action = "confirmSignout"
        rOpenDrawer("Sign out of VIPTV?",[{title:"Cancel",action:"close"},{title:"Sign out",action:"signout"}],"confirm")
    else if action = "confirmClearHistory"
        rOpenDrawer("Clear this profile's history?",[{title:"Cancel",action:"close"},{title:"Clear history",action:"clearHistory"}],"confirm")
    else if action = "clearHistory"
        rSend("DELETE",rProfilePath("/history"),invalid,"save:history")
    else if action = "signout"
        rSend("POST","/api/auth/logout",{},"auth:logout")
    else if action = "configureSource"
        m.sourceSchema = value.schema
        m.sourceDraft = {}
        m.sourceProviders = []
        rSourceForm()
    else if action = "sourceField"
        m.sourceField = value.field
        rTextInput(value.field.label,"sourceField",value.field.secret,RText(m.sourceDraft[value.field.id]))
    else if action = "saveSource"
        if RArray(m.sourceSchema.provider_choices).count() > 0 then m.sourceDraft.providers = m.sourceProviders
        rSend("PUT",rProfilePath("/source-integrations"),{revision:m.sourceSchemas.revision,plugin_id:m.sourceSchema.plugin_id,configuration:m.sourceDraft},"save:source")
    else if action = "sourceProviders"
        rProviderChoices()
    else if action = "sourceProvider"
        found = -1
        for i = 0 to m.sourceProviders.count()-1
            if m.sourceProviders[i] = value.value then found = i
        end for
        if found >= 0
            m.sourceProviders.delete(found)
        else if m.sourceProviders.count() < m.sourceSchema.maximum_providers
            m.sourceProviders.push(value.value)
        end if
        rProviderChoices()
    else if action = "sourceProvidersDone"
        rSourceForm()
    else if action = "removeSource"
        rOpenDrawer("Remove source integration?",[{title:"Cancel",action:"close"},{title:"Remove",action:"removeSourceConfirmed"}],"confirm")
    else if action = "removeSourceConfirmed"
        rSend("DELETE",rProfilePath("/source-integrations/"+REncode(m.sourceSchema.connection_id)+"?revision="+m.sourceSchemas.revision.toStr()),invalid,"save:source")
    else if action = "installAddon"
        rTextInput("Add-on manifest URL","installAddon",false,"")
    else if action = "toggleAddon"
        rSend("PUT",rProfilePath("/addon-activation"),{connection_id:value.connection.id,enabled:not value.enabled},"save:addons")
    else if action = "unlock"
        rTextInput("Parent PIN","unlock",true,"")
    else if action = "simkl"
        rSend("GET",rProfilePath("/simkl"),invalid,"settings:simkl")
    else if action = "confirmUnlink"
        rOpenDrawer("Disconnect Simkl?",[{title:"Cancel",action:"close"},{title:"Disconnect",action:"unlink"}],"confirm")
    else if action = "unlink"
        rSend("DELETE",rProfilePath("/simkl"),invalid,"save:simkl")
    else if action = "close"
        rCloseDrawer()
    else if left(action,7) = "player:"
        rPlayerAction(value)
    end if
end sub

sub rSourceForm()
    values = []
    for each field in RArray(m.sourceSchema.credential_fields)
        state = ""
        if RText(m.sourceDraft[field.id]) <> "" then state = "Entered"
        values.push({title:field.label,subtitle:state,action:"sourceField",field:field})
    end for
    if RArray(m.sourceSchema.provider_choices).count() > 0 then values.push({title:"Providers",subtitle:m.sourceProviders.count().toStr()+" selected",action:"sourceProviders"})
    values.push({title:"Save",action:"saveSource"})
    if RText(m.sourceSchema.connection_id) <> "" then values.push({title:"Remove integration",action:"removeSource"})
    rOpenDrawer(m.sourceSchema.name,values,"sourceForm")
end sub

sub rProviderChoices()
    values = [{title:"Done",action:"sourceProvidersDone"}]
    for each provider in RArray(m.sourceSchema.provider_choices)
        label = provider.label
        for each id in m.sourceProviders
            if id = provider.id then label = "✓ "+label
        end for
        values.push({title:label,action:"sourceProvider",value:provider.id})
    end for
    focus = m.drawerRows.itemFocused
    rOpenDrawer("Providers",values,"sourceProviders")
    if focus >= 0 and focus < values.count() then m.drawerRows.jumpToItem = focus
end sub

sub rSaved(tag as string, data as dynamic, request as object)
    m.revisionDue = 0
    rInvalidateReturnViews()
    if tag = "save:preferences"
        m.preferences = data
        if m.route <> "settings" or request.generation <> m.generation then return
        if m.drawer.visible and m.drawerKind <> "preference" then return
        rCloseDrawer()
        rSettingsSection(m.section)
    else if tag = "save:profile"
        m.profilesRefreshPending = true
        if not rProfileMutationCurrent(request) then return
        rRetireProfileEditor()
        m.keyboard.visible = false
        m.keyboard.text = ""
        m.drawerStack = []
        if m.drawer.visible then rCloseDrawer()
        rSend("GET","/api/profiles",invalid,"profiles")
    else if tag = "save:history"
        rNavigate("history")
    else if tag = "save:source"
        m.sourceDraft = {}
        rCloseDrawer()
        rSettingsSection("Source integrations")
    else if tag = "save:addons" or tag = "save:installAddon"
        rCloseDrawer()
        rSettingsSection("Add-ons")
    else if tag = "save:unlock"
        if not rPinCurrent(request) then return
        rFinishPinEditor()
        rCloseDrawer()
        rSettingsSection("Parental controls")
    else if tag = "save:unlockResume"
        if not rPinCurrent(request) then return
        q = m.afterParent
        m.afterParent = invalid
        rFinishPinEditor()
        if q <> invalid
            if rRequestCurrent(q)
                if q.tag = "save:profile" and RObject(m.profileForm) then rShowProfileDraft(true,"Saving…")
                rSend(q.method,q.path,q.body,q.tag,q.context,q.query)
                if q.tag = "save:profile" and not m.pending.doesExist(q.tag) then rShowProfileDraft(false,"The connection is busy. Try again.")
            end if
        end if
    else if tag = "save:simkl"
        rSend("GET",rProfilePath("/simkl"),invalid,"settings:simkl")
    else if tag = "save:library"
        m.homeData = invalid
        if request.method = "DELETE" then m.message.text = "Removed from My List" else m.message.text = "Saved to My List"
        if m.route = "library" then m.libraryRevisionPending = true
        if m.route = "detail" then rDetailPage(0)
        if m.route = "home" then rSend("GET",rProfilePath("/home"),invalid,"home")
    end if
end sub

sub rTextInput(title as string, purpose as string, secret as boolean, value as string)
    if purpose = "server" and m.route = "pairing"
        rCancelPairing()
        m.resumePairingAfterServer = true
    end if
    if purpose = "createProfile" or purpose = "renameProfile"
        rRetireProfileEditor()
        target = ""
        if purpose = "renameProfile"
            target = RText(RGet(m.editProfile,"id"))
            if target = ""
                rError("Refresh the profile list and try again.")
                return
            end if
        end if
        m.profileForm = {purpose:purpose,target:target,text:value,version:m.profileUiVersion}
    end if
    if purpose = "unlock" or purpose = "unlockResume"
        rRetirePinEditor()
        m.pinForm = {purpose:purpose,text:value,version:m.pinUiVersion}
    end if
    if purpose = "createProfile" or purpose = "renameProfile" or purpose = "unlock" or purpose = "unlockResume"
        rShowForm(purpose,value,false,"")
        return
    end if
    m.inputPurpose = purpose
    m.keyboard.busy = false
    m.keyboard.error = ""
    m.keyboard.searchMode = purpose = "search"
    m.keyboard.maxLength = 2048
    m.keyboard.prompt = title
    m.keyboard.secret = secret
    m.keyboard.text = value
    m.keyboard.visible = true
    m.top.removeChild(m.keyboard)
    m.top.appendChild(m.keyboard)
    m.keyboard.setFocus(true)
end sub

sub rTextDone()
    if not m.keyboard.visible or m.keyboard.busy then return
    if m.formEditing
        rFormEntryReturn(true)
        return
    end if
    text = m.keyboard.text
    purpose = m.inputPurpose
    if purpose = "search"
        m.searchTerm = text
        m.searchVersion++
        m.searchTick.control = "stop"
        rSearchSubmit()
        rSearchResultsFocus()
        return
    end if
    if purpose = "server" and ROrigin(text) = ""
        m.keyboard.error = "Enter an HTTPS origin without a path."
        return
    end if
    m.keyboard.visible = false
    m.keyboard.text = ""
    purpose = m.inputPurpose
    if purpose = "server"
        returnToPassword = m.route = "password"
        rForgetSession()
        m.config.base = ROrigin(text)
        m.config.auth_origin = m.config.base
        rSend("CONFIG_SAVE","",m.config,"auth:persist")
        if returnToPassword then rPassword() else rWelcome()

    else if purpose = "sourceField"
        m.sourceDraft[m.sourceField.id] = text
        rSourceForm()
    else if purpose = "installAddon"
        rSend("POST","/api/addons",{manifest_url:text},"save:installAddon")

    end if
end sub

sub rTextCancel()
    if not rInputVisible() then return
    if m.formEditing
        rFormEntryReturn(false)
        return
    end if
    if m.formDialog.visible and m.formDialog.busy and (m.inputPurpose = "unlock" or m.inputPurpose = "unlockResume") then return
    if m.inputPurpose = "createProfile" or m.inputPurpose = "renameProfile" then rRetireProfileEditor()
    if m.inputPurpose = "unlock" or m.inputPurpose = "unlockResume"
        rRetirePinEditor()
        if RObject(m.afterParent) and RObject(m.profileForm)
            if m.afterParent.tag = "save:profile" and rProfileMutationCurrent(m.afterParent)
                m.afterParent = invalid
                m.profileUiVersion++
                m.profileForm.version = m.profileUiVersion
                rShowProfileDraft(false,"Changes were not saved.")
                return
            end if
        end if
    end if
    search = m.keyboard.searchMode
    m.keyboard.visible = false
    m.keyboard.text = ""
    if RObject(m.afterParent)
        if rLiveDataTag(m.afterParent.tag) and rRequestCurrent(m.afterParent)
            m.failedRequest = m.afterParent
            m.liveFailureText = "Live access cancelled. Try again."
            m.liveRetryTag = ""
        else if m.afterParent.tag = "player:episodes"
            rPlayerFailure("player:episodes",{error:"Episode access cancelled."},m.afterParent)
        else if m.afterParent.tag = "player:start" or m.afterParent.tag = "player:poll"
            rAdmissionFailure("Playback request cancelled.")
        else if m.afterParent.tag = "save:preferences" and m.afterParent.generation = m.generation
            if m.drawer.visible then m.drawerMessage.text = "Changes were not saved." else m.message.text = "Changes were not saved."
        end if
    end if
    m.afterParent = invalid
    if m.inputPurpose = "server" and m.deferredBootstrap <> invalid
        data = m.deferredBootstrap
        m.deferredBootstrap = invalid
        m.bootstrapDeferred = false
        rBootstrap(data)
        return
    else if m.inputPurpose = "server" and m.bootstrapDeferred
        m.bootstrapDeferred = false
        rSend("GET","/api/bootstrap",invalid,"auth:bootstrap")
    end if
    if m.inputPurpose = "server" and m.resumePairingAfterServer
        m.resumePairingAfterServer = false
        if RText(m.config.access_token) <> "" then rSend("GET","/api/bootstrap",invalid,"auth:bootstrap") else rRun({action:"pair"})
        return
    end if
    if rRestoreFormOpener() then return
    if m.librarySheet.visible
        m.librarySheet.setFocus(true)
        m.librarySheet.callFunc("refresh")
    else if m.filterPage.visible
        m.filterPage.setFocus(true)
        m.filterPage.callFunc("refresh")
    else if m.route = "password"
        m.passwordForm.callFunc("focusKeyboard")
    else if search
        rNavigate("home")
    else if m.drawer.visible
        m.drawerRows.setFocus(true)
    else
        rFocusContent()
    end if
end sub

sub rTextChanged()
    m.keyboard.error = ""
    if m.route <> "search" or m.inputPurpose <> "search" or not m.keyboard.visible then return
    rRetireSearch()
    m.searchTerm = m.keyboard.text
    m.searchTick.control = "stop"
    m.searchTick.control = "start"
end sub

sub rSearchSubmit()
    if m.route <> "search" then return
    rRetireSearch()
    if RText(m.searchTerm).trim() = "" then return
    if m.searchMediaAllowed then rSend("GET","/api/search?query="+REncode(m.searchTerm),invalid,"search",{search_version:m.searchVersion})
    if m.searchChannelsAllowed then rSearchChannelFetch(invalid,"initial")
end sub

sub rSearchResultsFocus()
    if m.formDialog.visible or m.formEditing then return
    if m.shelves.visible and m.shelves.content <> invalid
        if m.searchFirstResult <> invalid
            target = m.searchResumeFocus
            if target = invalid then target = m.searchFirstResult
            m.shelves.jumpToRowItem = target
            m.shelves.setFocus(true)
        else if m.retryBar.visible
            m.retryBar.setFocus(true)
        end if
    else if m.retryBar.visible
        m.retryBar.setFocus(true)
    end if
end sub

sub rAddonRows()
    if not RObject(m.integrations) or not RObject(m.addonStates) then return
    values = [{title:"Install add-on",action:"installAddon"}]
    for each connection in RArray(m.integrations.connections)
        if connection.plugin_id = "stremio"
            for each state in RArray(m.addonStates.addons)
                if state.connection_id = connection.id and GetInterface(state.enabled,"ifBoolean") <> invalid
                    label = "Disabled"
                    if state.enabled then label = "Enabled"
                    values.push({title:connection.name,subtitle:label,action:"toggleAddon",connection:connection,enabled:state.enabled})
                    exit for
                end if
            end for
        end if
    end for
    rShowRows(values)
end sub

function rPreferenceBusy() as boolean
    if m.pending.doesExist("save:preferences") or m.pending.doesExist("settings:preferences") then return true
    for each request in m.retryAuth
        if request.tag = "save:preferences" then return true
    end for
    return RGet(m.afterParent,"tag") = "save:preferences"
end function
