' Preserve the existing origin-bound rotating device grant. No local library.


function rStored(value as dynamic, packaged as dynamic) as object
    base = ROrigin(RGet(value,"base",RGet(value,"server")))
    locked = ROrigin(RGet(packaged,"base")) <> ""
    if locked then base = ROrigin(packaged.base)
    result = {base:base,locked:locked,access_token:"",refresh_token:"",last_profile_id:"",account_id:"",auth_origin:base,auth_version:3}
    if RGet(value,"auth_origin") = base and (RGet(value,"auth_version") = 2 or RGet(value,"auth_version") = 3)
        refresh = RText(value.refresh_token)
        access = RText(value.access_token)
        if value.auth_version = 2 and access = "" then access = RText(value.token)
        safe = CreateObject("roRegex","^[!-~]{1,4096}$","")
        if safe.isMatch(refresh) and safe.isMatch(access)
            result.access_token = access
            result.refresh_token = refresh
            result.last_profile_id = RText(value.last_profile_id)
            result.account_id = RText(value.account_id)
            if value.auth_version = 2 and result.last_profile_id = "" then result.last_profile_id = RText(value.profile)
        end if
    end if
    return result
end function

function rStore(q as object, result as object) as object
    registry = CreateObject("roRegistrySection","VIPTV")
    packaged = invalid
    path = "pkg:/data/connection.json"
    file = CreateObject("roFileSystem").stat(path)
    if file <> invalid
        if RGet(file,"size",0) > 0 and RGet(file,"size",0) <= 4096
            packaged = ParseJson(ReadAsciiFile(path))
            if not RObject(packaged) then packaged = invalid
        end if
    end if
    if q.method = "CONFIG_SAVE"
        document = rStored(q.body,packaged)
        if document.base = ""
            result.error = "Enter a secure HTTPS server address."
            return result
        end if
        saved = registry.write("config",FormatJson(document))
        registry.delete("token")
        registry.delete("server")
        registry.delete("profile")
        if not registry.flush() or not saved
            result.error = "This TV could not save its sign-in. Try again."
            return result
        end if
    end if
    stored = registry.read("config")
    value = invalid
    if stored <> "" then value = ParseJson(stored)
    if not RObject(value) then value = {base:registry.read("server")}
    result.data = rStored(value,packaged)
    result.data.capabilities = rDeviceFacts()
    result.ok = true
    return result
end function

function rDeviceFacts() as object
    caps = {max_width:1280,max_height:720,h264:false,hevc:false,aac:false}
    device = CreateObject("roDeviceInfo")
    caps.h264 = RGet(device.canDecodeVideo({codec:"mpeg4 avc",profile:"high",level:"4.1",container:"hls"}),"result",false)
    caps.hevc = RGet(device.canDecodeVideo({codec:"hevc",profile:"main",level:"5.0",container:"hls"}),"result",false)
    caps.aac = RGet(device.canDecodeAudio({codec:"aac"}),"result",false)
    mode = lcase(device.getVideoMode())
    if instr(1,mode,"1080") > 0 or instr(1,mode,"2160") > 0
        caps.max_width = 1920
        caps.max_height = 1080
    end if
    avc4k = RGet(device.canDecodeVideo({codec:"mpeg4 avc",profile:"high",level:"5.1",container:"hls"}),"result",false)
    if caps.hevc and avc4k and instr(1,mode,"2160") > 0
        caps.max_width = 3840
        caps.max_height = 2160
    end if
    return caps
end function
