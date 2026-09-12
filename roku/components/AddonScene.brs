' Account-owned addons are shared across profiles; provider administration stays server-only.
sub addonResponse(tag as string, result as object)
    if not result.ok
        m.status.text = Txt(result.error,"Could not update addons.")
        return
    end if
    if tag = "addonchanged"
        clearHomeCache()
        request("GET","/api/addons",invalid,"accountaddons")
        return
    end if
    values = [{name:"Install addon",action:"installaddon",description:"Enter a Stremio manifest URL."}]
    for each item in Bounded(result.data,100)
        item.action = "manageaddon"
        item.description = "Disabled"
        if item.enabled = true then item.description = "Enabled"
        values.push(item)
    end for
    rows("Addons",values,"addons","Shared by all profiles and devices on your account.")
end sub

sub addonChoice(choice as object)
    item = m.managedAddon
    if item = invalid then return
    path = "/api/addons/" + Enc(Txt(item.id))
    if choice.action = "toggleaddon"
        request("PATCH",path,{enabled:item.enabled <> true},"addonchanged")
    else if choice.action = "removeaddon"
        uiOpenChoice("removeAddon","Remove " + Txt(item.name) + "?",[{name:"Cancel",action:"cancel"},{name:"Remove",action:"confirmRemoveAddon"}])
    else if choice.action = "confirmRemoveAddon"
        request("DELETE",path,invalid,"addonchanged")
    end if
end sub
