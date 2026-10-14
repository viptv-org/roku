' Private selection intent is consumed here, never forwarded as a source URL or API credential.
function RokuPrepareProviderCaption(request as object, session as object, timeoutMs as integer) as object
    result = {tag:request.tag,ok:true,data:session,error:"",status:200}
    subtitle = StablePreferenceText(request.body.external_subtitle_id,128)
    if subtitle = "" then return result
    if session.external_subtitles_supported <> true or session.live = true
        result.ok = false : result.error = "External subtitles are unavailable for this playback."
        return result
    end if
    control = EngineRequestCopy(request)
    control.path = "/api/v2/playback/"+Enc(Txt(session.id))+"/subtitles"
    control.body = {subtitle_id:subtitle}
    control.timeout_ms = timeoutMs
    if control.timeout_ms > 15000 then control.timeout_ms = 15000
    result = HttpRequestRaw(control,RokuPlaybackV2Empty(request.tag),"POST",false)
    if not result.ok then return result
    value = result.data
    if not AccountIsObject(value) or Txt(value.format) <> "srt" or not RokuCaptionUrl(Txt(session.url),Txt(value.url))
        result.ok = false : result.data = invalid : result.error = "The server returned an invalid subtitle rendition."
        return result
    end if
    session.provider_caption = {url:value.url,format:"srt",language:left(Txt(value.language),32),label:left(Txt(value.label),256),subtitle_id:subtitle}
    result.data = session
    return result
end function

function RokuCaptionUrl(media as string, caption as string) as boolean
    if left(media,8) <> "https://" or left(caption,8) <> "https://" then return false
    unsafe = CreateObject("roRegex","[\x00-\x20\\#?]","")
    if unsafe.isMatch(media) or unsafe.isMatch(caption) then return false
    slash = 0
    for i = 9 to len(media)
        if mid(media,i,1) = "/" then slash = i
    end for
    if slash = 0 then return false
    base = left(media,slash)
    if left(caption,len(base)) <> base then return false
    filename = mid(caption,len(base)+1)
    return CreateObject("roRegex","^[A-Za-z0-9_-]+[.]srt$","").isMatch(filename)
end function
