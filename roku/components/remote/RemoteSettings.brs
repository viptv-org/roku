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
    m.navigation.visible = false
    sections = [{title:"Account",action:"section",section:"Account"},{title:"Profiles",action:"profiles"},{title:"Playback",action:"section",section:"Playback"},{title:"Subtitles & audio",action:"section",section:"Subtitles & audio"},{title:"Add-ons",action:"section",section:"Add-ons"},{title:"Source integrations",action:"section",section:"Source integrations"},{title:"Parental controls",action:"section",section:"Parental controls"},{title:"About",action:"section",section:"About"}]
    for each item in sections
        item.sidebar = true
        item.ring = false
        item.selected = item.section = section
        icons = {Account:"profile",Profiles:"remote-users",Playback:"remote-play","Subtitles & audio":"remote-captions","Add-ons":"addons","Source integrations":"remote-server","Parental controls":"remote-lock",About:"info"}
        item.icon = icons[item.title]
    end for
    m.settingsNav.content = rContent(sections,440,72)
    m.heading.text = section
    m.heading.translation = [640,93]
    m.heading.width = 1184
    m.heading.font.size = 40
    m.rows.translation = [640,220]
    m.rows.itemSize = [1184,104]
    m.skeleton.visible = true
    if section = "Playback" or section = "Subtitles & audio"
        rSend("GET",rProfilePath("/preferences"),invalid,"settings:preferences")
    else if section = "Source integrations"
        rSend("GET",rProfilePath("/source-integrations"),invalid,"settings:sources")
    else if section = "Add-ons"
        rSend("GET",rProfilePath("/integrations"),invalid,"settings:integrations")
    else if section = "Parental controls"
        rSend("GET","/api/parent/status",invalid,"settings:parent")
    else if section = "Account"
        rShowRows([{title:"Sign out",action:"confirmSignout"},{title:"Simkl",action:"simkl"}])
    else if section = "About"
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
                    if FormatJson(choice.value) = FormatJson(data.preferences[control.id]) then label = choice.label
                end for
                values.push({title:control.label,subtitle:label,action:"preference",field:control.id,choices:control.choices})
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
        values = [{title:"Install add-on",action:"installAddon"}]
        for each connection in RArray(data.connections)
            if connection.plugin_id = "stremio"
                enabled = false
                for each assignment in RArray(data.configuration.assignments)
                    if assignment.connection_id = connection.id then enabled = RArray(assignment.enabled).count() > 0
                end for
                state = "Disabled"
                if enabled then state = "Enabled"
                values.push({title:connection.name,subtitle:state,action:"toggleAddon",connection:connection,enabled:enabled})
            end if
        end for
        rShowRows(values)
    else if tag = "settings:parent"
        m.parentAccess = data
        values = []
        if data.pin_configured = true and data.unlocked <> true then values.push({title:"Unlock parental controls",action:"unlock"})
        if data.unlocked = true
            values.push({title:"Kids profiles",action:"kidsProfiles"})
        end if
        rShowRows(values)
        if data.pin_configured <> true then m.message.text = "Set up your parent PIN from your account at "+m.config.base
    else if tag = "settings:kids"
        m.kidsPolicy = data
        state = "Off"
        if data.enabled = true then state = "On"
        rOpenDrawer("Parental controls",[{title:"Kids profile",subtitle:state,action:"kidsToggle"},{title:"Age limit",subtitle:data.max_age.toStr(),action:"kidsAge"},{title:"Approved titles",action:"approvedTitles"}],"kids")
    else if tag = "settings:approvals"
        values = [{title:"Approve a title",action:"parentSearch"}]
        for each entry in RArray(data.items)
            values.push({title:RText(entry.name),subtitle:"Approved",action:"removeApproval",approval:entry})
        end for
        rOpenDrawer("Approved titles",values,"approvals")
    else if tag = "settings:parentSearch"
        values = []
        for each entry in RArray(data.items)
            if entry.approval_supported = true then values.push({title:RText(entry.name),action:"approveTitle",approval:entry})
        end for
        rOpenDrawer("Approve a title",values,"approvals")
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
    if action = "section"
        rSettingsSection(value.section)
    else if action = "preference"
        choices = []
        for each choice in value.choices
            choices.push({title:choice.label,action:"savePreference",field:value.field,value:choice.value})
        end for
        rOpenDrawer(value.title,choices,"preference")
    else if action = "savePreference"
        p = ParseJson(FormatJson(m.preferences.preferences))
        p[value.field] = value.value
        rSend("PUT",rProfilePath("/preferences"),{revision:m.preferences.revision,preferences:p},"save:preferences")
    else if action = "createProfile"
        rTextInput("Profile name","createProfile",false,"")
    else if action = "manageProfiles"
        values = []
        for each profile in RArray(m.management.profiles)
            values.push({title:profile.name,action:"editProfile",profile:profile})
        end for
        rOpenDrawer("Manage profiles",values,"profiles")
    else if action = "editProfile"
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
        rSend("PATCH","/api/profiles/"+REncode(m.editProfile.id),{avatar_id:value.value},"save:profile")
    else if action = "confirmDeleteProfile"
        rOpenDrawer("Delete "+m.editProfile.name+"?",[{title:"Cancel",action:"close"},{title:"Delete profile",action:"deleteProfile"}],"confirm")
    else if action = "deleteProfile"
        rSend("DELETE","/api/profiles/"+REncode(m.editProfile.id),invalid,"save:profile")
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
    else if action = "kidsProfiles"
        values = []
        for each p in RArray(m.management.profiles)
            values.push({title:p.name,action:"kidsProfile",profile:p})
        end for
        rOpenDrawer("Kids profiles",values,"kidsProfiles")
    else if action = "kidsProfile"
        m.kidsProfile = value.profile
        rSend("GET","/api/profiles/"+REncode(value.profile.id)+"/kids",invalid,"settings:kids")
    else if action = "kidsToggle"
        rSend("PUT","/api/profiles/"+REncode(m.kidsProfile.id)+"/kids",{enabled:not m.kidsPolicy.enabled,max_age:m.kidsPolicy.max_age},"save:kids")
    else if action = "kidsAge"
        values = []
        for age = 0 to 17
            values.push({title:age.toStr(),action:"saveAge",age:age})
        end for
        rOpenDrawer("Age limit",values,"kidsAge")
    else if action = "saveAge"
        rSend("PUT","/api/profiles/"+REncode(m.kidsProfile.id)+"/kids",{enabled:m.kidsPolicy.enabled,max_age:value.age},"save:kids")
    else if action = "approvedTitles"
        rSend("GET","/api/profiles/"+REncode(m.kidsProfile.id)+"/approvals",invalid,"settings:approvals")
    else if action = "parentSearch"
        rTextInput("Find a title to approve","parentSearch",false,"")
    else if action = "approveTitle" or action = "removeApproval"
        entry = value.approval
        body = {type:entry.type,id:entry.id}
        for each key in ["metadata_provider_id","metadata_addon_id","metadata_origin","card"]
            if entry[key] <> invalid then body[key] = entry[key]
        end for
        body.approved = action = "approveTitle"
        rSend("POST","/api/profiles/"+REncode(m.kidsProfile.id)+"/approvals",body,"save:approval")
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
    if left(tag,14) <> "save:progress:" and left(tag,11) <> "save:event:"
        m.snapshots = []
    end if
    if tag = "save:preferences"
        m.preferences = data
        rCloseDrawer()
        rSettingsSection(m.section)
    else if tag = "save:profile"
        rCloseDrawer()
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
        rCloseDrawer()
        rSettingsSection("Parental controls")
    else if tag = "save:unlockResume"
        q = m.afterParent
        m.afterParent = invalid
        if q <> invalid
            if q.epoch = m.epoch and q.generation = m.generation then rSend(q.method,q.path,q.body,q.tag,q.context)
        end if
    else if tag = "save:kids"
        rSend("GET","/api/profiles/"+REncode(m.kidsProfile.id)+"/kids",invalid,"settings:kids")
    else if tag = "save:approval"
        rSend("GET","/api/profiles/"+REncode(m.kidsProfile.id)+"/approvals",invalid,"settings:approvals")
    else if tag = "save:simkl"
        rSend("GET",rProfilePath("/simkl"),invalid,"settings:simkl")
    else if tag = "save:library"
        if request.method = "DELETE" then m.message.text = "Removed from My List" else m.message.text = "Saved to My List"
        if m.route = "detail" then rDetailPage(0)
        if m.route = "home" then rSend("GET",rProfilePath("/home"),invalid,"home")
    end if
end sub

sub rTextInput(title as string, purpose as string, secret as boolean, value as string)
    m.inputPurpose = purpose
    m.keyboard.searchMode = purpose = "search"
    m.keyboard.prompt = title
    m.keyboard.secret = secret
    m.keyboard.text = value
    m.keyboard.visible = true
    m.top.removeChild(m.keyboard)
    m.top.appendChild(m.keyboard)
    m.keyboard.setFocus(true)
end sub

sub rTextDone()
    text = m.keyboard.text
    m.keyboard.visible = false
    m.keyboard.text = ""
    purpose = m.inputPurpose
    if purpose = "search"
        m.searchTerm = text
        rSend("GET","/api/search?query="+REncode(text),invalid,"search")
    else if purpose = "username"
        m.loginUser = text
        rTextInput("Password","password",true,"")
    else if purpose = "password"
        rSend("POST","/api/auth/device/login",{username:m.loginUser,password:text,device_name:"VIPTV Roku"},"auth:login")
        m.loginUser = ""
    else if purpose = "server"
        if ROrigin(text) = ""
            rError("Enter an HTTPS origin without a path.")
            return
        end if
        rForgetSession()
        m.config.base = ROrigin(text)
        m.config.auth_origin = m.config.base
        rSend("CONFIG_SAVE","",m.config,"auth:persist")
        rWelcome()
    else if purpose = "createProfile"
        rSend("POST","/api/profiles",{name:text},"save:profile")
    else if purpose = "renameProfile"
        rSend("PATCH","/api/profiles/"+REncode(m.editProfile.id),{name:text},"save:profile")
    else if purpose = "sourceField"
        m.sourceDraft[m.sourceField.id] = text
        rSourceForm()
    else if purpose = "installAddon"
        rSend("POST","/api/addons",{manifest_url:text},"save:installAddon")
    else if purpose = "unlock"
        rSend("POST","/api/parent/unlock",{pin:text},"save:unlock")
    else if purpose = "unlockResume"
        rSend("POST","/api/parent/unlock",{pin:text},"save:unlockResume")
    else if purpose = "filter"
        m.selectedValues = [text]
        rApplyFilter()
    else if purpose = "parentSearch"
        rSend("GET","/api/parent/search?query="+REncode(text)+"&profile_id="+REncode(m.kidsProfile.id),invalid,"settings:parentSearch")
    end if
end sub

sub rTextCancel()
    search = m.keyboard.searchMode
    m.keyboard.visible = false
    m.keyboard.text = ""
    m.afterParent = invalid
    if search
        rNavigate("home")
    else if m.drawer.visible
        m.drawerRows.setFocus(true)
    else
        rFocusContent()
    end if
end sub

sub rTextChanged()
    if m.route <> "search" or not m.keyboard.visible then return
    m.searchVersion++
    m.searchTerm = m.keyboard.text
    m.searchTick.control = "stop"
    m.searchTick.control = "start"
end sub

sub rSearchSubmit()
    if m.route <> "search" then return
    for each worker in m.workers
        if worker.request.tag = "search" then worker.cancel = true
    end for
    m.pending.delete("search")
    if m.searchTerm.trim() = ""
        m.shelves.visible = false
        return
    end if
    rSend("GET","/api/search?query="+REncode(m.searchTerm),invalid,"search",{search_version:m.searchVersion})
end sub

sub rSearchResultsFocus()
    if m.shelves.visible and m.shelves.content <> invalid
        if m.shelves.content.getChildCount() > 0 then m.shelves.setFocus(true)
    end if
end sub
