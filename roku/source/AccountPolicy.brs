' Closed account-only auth wire policy. No credential is used as a cache key.
function AccountIsObject(value as dynamic) as boolean
    return GetInterface(value,"ifAssociativeArray") <> invalid
end function

function AccountClamp(value as integer, low as integer, high as integer) as integer
    if value < low then return low
    if value > high then return high
    return value
end function

function AccountErrorCode(text as string) as string
    if len(text) > 4096 then return ""
    for each code in ["authorization_pending","slow_down","expired_token","access_denied","invalid_grant","revoked","device_revoked","invalid_token","profile_required","profile_policy_changed","parent_required","parent_pin_invalid"]
        q = chr(34)
        pattern = q + "(?:error|error_code)" + q + "\s*:\s*" + q + code + q
        if CreateObject("roRegex",pattern,"").isMatch(text) then return code
    end for
    return ""
end function

function AccountOrigin(value as dynamic) as string
    origin = Txt(value).trim()
    pattern = CreateObject("roRegex","^https?://(\[[0-9a-f:.]+\]|[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(:[0-9]{1,5})?/?$","i")
    if not pattern.isMatch(origin) or instr(1,origin,"..") > 0 then return ""
    if right(origin,1) = "/" then origin = left(origin,len(origin)-1)
    return origin
end function

function AccountAvatarStyles() as object
    ' These DiceBear 10.x styles are listed as CC0 and include kid-friendly choices.
    return ["critters","pixel-art","pixel-art-neutral","moods","thumbs","lorelei","notionists","pixelbot","voxel-bot","sprouts","planets","clay","disney","princesses","animal-friends","villains"]
end function

function AccountAvatarStyle(value as dynamic) as string
    candidate = lcase(Txt(value).trim())
    for each style in AccountAvatarStyles()
        if candidate = style then return style
    end for
    return ""
end function

function AccountAvatarUrl(value as dynamic) as string
    url = Txt(value).trim()
    if url = "" or len(url) > 2048 then return ""
    if CreateObject("roRegex","[\x00-\x20\\#]","").isMatch(url) then return ""
    ' Character image URLs must match the bundled, curated catalog exactly.
    characters = ParseJson(ReadAsciiFile("pkg:/data/character-avatars.json"))
    if characters <> invalid
        for each style in characters
            for each item in characters[style]
                if url = item.url then return url
            end for
        end for
    end if
    prefix = "https://api.dicebear.com/10.x/"
    if left(url,len(prefix)) <> prefix then return ""
    rest = mid(url,len(prefix)+1)
    slash = instr(1,rest,"/")
    if slash <= 1 then return ""
    if AccountAvatarStyle(left(rest,slash-1)) = "" then return ""
    if left(mid(rest,slash+1),4) <> "png?" then return ""
    return url
end function

function AccountProfileRow(profile as dynamic) as dynamic
    if not AccountIsObject(profile) then return invalid
    id = left(Txt(profile.id),128)
    if id = "" then return invalid
    name = left(Txt(profile.name),128)
    style = AccountAvatarStyle(profile.avatar_style)
    avatar = AccountAvatarUrl(profile.avatar_url)
    complete = false
    if GetInterface(profile.setup_complete,"ifBoolean") <> invalid
        complete = profile.setup_complete
    else if GetInterface(profile.presentation_complete,"ifBoolean") <> invalid
        ' Temporary migration compatibility for pre-1.6 servers.
        complete = profile.presentation_complete
    end if
    row = {id:id,name:name,avatar_url:avatar,avatar_style:style,avatar_choice:profile.avatar_choice,setup_complete:complete,presentation_complete:complete}
    if GetInterface(profile.is_primary,"ifBoolean") <> invalid then row.is_primary = profile.is_primary
    return row
end function

function AccountProfileRows(profiles as dynamic, allowCreate as boolean) as object
    values = []
    for each profile in Bounded(profiles,20)
        row = AccountProfileRow(profile)
        if row <> invalid then values.push(row)
    end for
    if allowCreate and values.count() < 5
        values.push({name:"Add profile",action:"newprofile",presentation_complete:true})
    end if
    return values
end function

function AccountWire(route as string, data as dynamic) as object
    if left(route,17) = "/api/auth/device/" then route = "/api/device/" + mid(route,18)
    failure = {ok:false,data:invalid}
    if not AccountIsObject(data) then return failure
    out = {}
    for each key in ["account_id","profile_id","device_id","session_id","role","user_code","verification_uri","verification_uri_complete","qr_uri","status"]
        if data.doesExist(key) then out[key] = left(Txt(data[key]),2048)
    end for
    for each key in ["access_token","refresh_token","device_code"]
        if data.doesExist(key)
            value = Txt(data[key])
            if not CreateObject("roRegex","^[!-~]{1,4096}$","").isMatch(value) then return failure
            out[key] = value
        end if
    end for
    for each key in ["expires_in","interval"]
        if data.doesExist(key)
            if not MatchInteger(data[key],1,2592000) then return failure
            out[key] = data[key]
        end if
    end for
    for each key in ["registration_enabled","can_create_profile","authenticated","restricted","unlocked"]
        if GetInterface(data[key],"ifBoolean") <> invalid then out[key] = data[key]
    end for
    if AccountIsObject(data.account) then out.account_id = Txt(data.account.id)
    if AccountIsObject(data.permissions)
        if GetInterface(data.permissions.create_profile,"ifBoolean") <> invalid then out.can_create_profile = data.permissions.create_profile
    end if
    if AccountIsObject(data.capabilities)
        if GetInterface(data.capabilities.create_profiles,"ifBoolean") <> invalid then out.can_create_profile = data.capabilities.create_profiles
        if GetInterface(data.capabilities.can_create_profile,"ifBoolean") <> invalid then out.can_create_profile = data.capabilities.can_create_profile
    end if
    if GetInterface(data.can_create_profile,"ifBoolean") <> invalid then out.can_create_profile = data.can_create_profile
    if GetInterface(data.profiles,"ifArray") <> invalid then out.profiles = AccountProfileRows(data.profiles,false)
    if route = "/api/device/code"
        if Txt(out.device_code) = "" or Txt(out.user_code) = "" or out.expires_in = invalid then return failure
        if not CreateObject("roRegex","^[A-Z0-9]{6,12}$","").isMatch(out.user_code) then return failure
        if left(Txt(out.verification_uri_complete),8) <> "https://" then return failure
        qr = Txt(out.qr_uri)
        if qr <> "" and left(qr,5) <> "/api/" and left(qr,8) <> "https://" then return failure
        if out.interval = invalid then out.interval = 5
    else if route = "/api/device/token" or route = "/api/device/refresh"
        if Txt(out.access_token) = "" or Txt(out.refresh_token) = "" or out.expires_in = invalid then return failure
    end if
    return {ok:true,data:out}
end function

' Separate people from controls and keep the TV scene bounded to five avatars.
function AccountProfilePage(profiles as object,index as integer) as object
    count = int((profiles.count()+4)/5)
    if count < 1 then count = 1
    if index < 0 then index = count-1
    if index >= count then index = 0
    items = []
    for i = index*5 to index*5+4
        if i < profiles.count() then items.push(profiles[i])
    end for
    return {items:items,index:index,count:count}
end function

function AccountProfileButtons(count as integer,allowed as boolean,managing as boolean) as object
    items = []
    if allowed and count < 12 then items.push({name:"Add profile",action:"newprofile"})
    if managing
        items.push({name:"Done",action:"profilesdone"})
    else if allowed
        items.push({name:"Manage profiles",action:"manageprofiles"})
    end if
    return items
end function
