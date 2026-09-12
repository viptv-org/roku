' Pure, render-thread-safe helpers; no network, registry or device queries.
function TrackOwner(item as object) as string
    if Txt(item.type) = "live" then return "live:" + Txt(item.id)
    return "source:" + Txt(item.stream_id,Txt(item.id))
end function

function TrackRequestFields(item as object, preferences as dynamic) as object
    fields = {}
    if GetInterface(preferences,"ifAssociativeArray") = invalid then return fields
    if Txt(preferences.owner) <> TrackOwner(item) then return fields
    for each key in ["audio_track_index","subtitle_track_index"]
        if MatchInteger(preferences[key],0,65535) then fields[key] = preferences[key]
    end for
    if preferences.subtitles_off = true then fields.subtitles_off = true
    return fields
end function

function StablePreferenceText(value as dynamic, maximum as integer) as string
    text = Txt(value).trim()
    if text = "" or len(text) > maximum then return ""
    unsafe = CreateObject("roRegex","[\x00-\x1f\x7f]","")
    if unsafe.isMatch(text) then return ""
    return text
end function

function StableSourcePreference(item as object) as object
    ' Server-authored addon/IPTV identity is stable across discovery jobs.
    ' Human/provider `source` text and opaque stream IDs never authorize resume.
    addonId = StablePreferenceText(item.source_addon_id,128)
    if addonId = "" then addonId = StablePreferenceText(item.addon_id,128)
    sourceName = Txt(item.source_name,Txt(item.name))
    sourceName = CreateObject("roRegex","[\r\n\t]+","").replaceAll(sourceName," ")
    sourceName = StablePreferenceText(sourceName,256)
    if addonId = "" or sourceName = "" then return {}
    result = {source_addon_id:addonId,source_name:sourceName}
    fingerprint = StablePreferenceText(item.source_fingerprint,64)
    if fingerprint <> "" then result.source_fingerprint = fingerprint
    for each key in ["source_binge_group","source_release_group","source_quality","source_audio","audio_language"]
        value = StablePreferenceText(item[key],128)
        if value <> "" then result[key] = value
    end for
    return result
end function

function SourceMatchesPreference(item as object, preference as dynamic) as boolean
    if GetInterface(preference,"ifAssociativeArray") = invalid then return false
    expected = StableSourcePreference(preference)
    actual = StableSourcePreference(item)
    if expected.source_addon_id = invalid or actual.source_addon_id = invalid then return false
    if Txt(expected.source_fingerprint) = "" then return false
    return actual.source_addon_id = expected.source_addon_id and Txt(actual.source_fingerprint) = Txt(expected.source_fingerprint)
end function

function StableResumePreference(item as object) as dynamic
    if item.position = invalid or item.position <= 0 then return invalid
    preference = StableSourcePreference(item)
    if preference.source_addon_id = invalid or Txt(preference.source_fingerprint) = "" then return invalid
    return preference
end function

function NativeSubtitleTrackId(tracks as dynamic) as string
    fallback = ""
    for each track in Bounded(tracks,32)
        id = Txt(track.TrackName,Txt(track.id))
        if id <> ""
            if fallback = "" then fallback = id
            if instr(1,lcase(id),"vtt") > 0 then return id
        end if
    end for
    return fallback
end function

function PlayerTrackSelectable(track as object) as boolean
    if track.selectable <> invalid then return track.selectable = true
    return track.supported = true
end function

function PlayerTrackLabel(track as object) as string
    language = Txt(track.language)
    names = {eng:"English",en:"English",ita:"Italian",it:"Italian",spa:"Spanish",es:"Spanish",fra:"French",fre:"French",fr:"French",deu:"German",ger:"German",de:"German",por:"Portuguese",pt:"Portuguese",jpn:"Japanese",ja:"Japanese"}
    if names.doesExist(lcase(language)) then language = names[lcase(language)]
    if language = "" then language = "Unverified language"
    title = CleanSourceLabel(Txt(track.title),false)
    if title = "" then title = "Track " + Txt(track.input_index)
    return language + " · " + title
end function

function LiveChannelPath(category as string, search as string, offset as integer) as string
    if offset < 0 then offset = 0
    return "/api/live?limit=80&offset=" + offset.toStr() + "&search=" + Enc(search) + "&category=" + Enc(category)
end function

function PlayerTime(value as dynamic) as string
    if value = invalid then return "--:--"
    if value < 0 then return "--:--"
    seconds = int(value)
    minutes = int(seconds / 60)
    tail = right("0" + (seconds mod 60).toStr(),2)
    if minutes < 60 then return minutes.toStr() + ":" + tail
    return int(minutes/60).toStr() + ":" + right("0" + (minutes mod 60).toStr(),2) + ":" + tail
end function

function ClampPlayerSeek(position as double, duration as double) as double
    if position < 0 then position = 0
    if duration > 0 and position >= duration then position = duration - 1
    if position < 0 then position = 0
    return position
end function

function Txt(value as dynamic, fallback = "" as string) as string
    if value = invalid then return fallback
    if GetInterface(value, "ifString") <> invalid then return value
    if GetInterface(value, "ifInt") <> invalid or GetInterface(value, "ifLongInt") <> invalid or GetInterface(value, "ifFloat") <> invalid or GetInterface(value, "ifDouble") <> invalid then return value.ToStr().Trim()
    if GetInterface(value, "ifBoolean") <> invalid
        if value then return "true"
        return "false"
    end if
    return fallback
end function

function Enc(value as string) as string
    bytes = CreateObject("roByteArray")
    bytes.FromAsciiString(value)
    hex = "0123456789ABCDEF"
    output = ""
    for i = 0 to bytes.Count() - 1
        b = bytes[i]
        if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or (b >= 48 and b <= 57) or b = 45 or b = 46 or b = 95 or b = 126
            output += Chr(b)
        else
            output += "%" + Mid(hex, Int(b / 16) + 1, 1) + Mid(hex, (b mod 16) + 1, 1)
        end if
    end for
    return output
end function

' Base denotes a server mount, not a document: relative paths append to it.
' Root-relative paths replace its path. Unsafe schemes/credentials are rejected.
function ResolveUrl(base as string, url as string) as string
    target = url.Trim()
    root = base.Trim()
    if target = "" then return ""
    if Left(target, 2) = "//" then return ""
    absolute = CreateObject("roRegex", "^https?://[^/?#@\s]+(?:[/?#].*)?$", "i")
    unsafe = CreateObject("roRegex", "[\x00-\x20\\]", "")
    if unsafe.IsMatch(target) then return ""
    if absolute.IsMatch(target) then return target
    scheme = CreateObject("roRegex", "^[a-z][a-z0-9+.-]*:", "i")
    if scheme.IsMatch(target) then return ""
    if not absolute.IsMatch(root) or unsafe.IsMatch(root) then return ""
    for each marker in ["?", "#"]
        at = Instr(1, root, marker)
        if at > 0 then root = Left(root, at - 1)
    end for
    if Left(target, 1) = "/"
        start = Instr(1, root, "://") + 3
        slash = Instr(start, root, "/")
        if slash > 0 then root = Left(root, slash - 1)
    else
        while Right(root, 1) = "/"
            root = Left(root, Len(root) - 1)
        end while
        target = "/" + target
    end if
    return root + target
end function

function Bounded(items as dynamic, limit as integer) as object
    output = []
    if GetInterface(items, "ifArray") = invalid or limit <= 0 then return output
    for each item in items
        if output.Count() >= limit then exit for
        output.Push(item)
    end for
    return output
end function

' Bounded deep copies retain integer epoch precision (JSON roundtrips may coerce
' timestamps to single-precision floats on interpreters/devices).
function CopyRouteData(value as dynamic, depth = 0 as integer) as dynamic
    if depth > 8 then return invalid
    if GetInterface(value,"ifArray") <> invalid
        copied = []
        for each item in Bounded(value,100)
            copied.push(CopyRouteData(item,depth+1))
        end for
        return copied
    end if
    if GetInterface(value,"ifAssociativeArray") <> invalid
        copied = {}
        for each key in value
            if copied.count() >= 64 then exit for
            copied[key] = CopyRouteData(value[key],depth+1)
        end for
        return copied
    end if
    if value = invalid then return invalid
    if GetInterface(value,"ifString") <> invalid or GetInterface(value,"ifBoolean") <> invalid then return value
    if GetInterface(value,"ifInt") <> invalid or GetInterface(value,"ifLongInt") <> invalid or GetInterface(value,"ifFloat") <> invalid or GetInterface(value,"ifDouble") <> invalid then return value
    return invalid
end function

function PlaybackBody(item as object, profile as dynamic, capabilities as dynamic, position as dynamic, force as boolean) as object
    caps = {max_width:1280,max_height:720,h264:true,hevc:false,aac:true,direct_play:false,hevc_sdr:false}
    if GetInterface(capabilities,"ifAssociativeArray") <> invalid
        if (capabilities.max_width = 1920 and capabilities.max_height = 1080) or (capabilities.max_width = 3840 and capabilities.max_height = 2160)
            caps.max_width = capabilities.max_width
            caps.max_height = capabilities.max_height
        end if
        for each field in ["direct_play","hevc","hevc_sdr"]
            if GetInterface(capabilities[field],"ifBoolean") <> invalid then caps[field] = capabilities[field]
        end for
    end if
    seconds = 0
    if GetInterface(position, "ifInt") <> invalid or GetInterface(position, "ifLongInt") <> invalid or GetInterface(position, "ifFloat") <> invalid or GetInterface(position, "ifDouble") <> invalid
        if position > 0 then seconds = position
    end if
    body = { capabilities: caps, position: seconds, force_transcode: force }
    ' The authenticated session owns the selected profile; playback carries no profile override.
    if Txt(item.type) = "live"
        body.channel_id = Txt(item.id)
    else
        body.stream_id = Txt(item.stream_id, Txt(item.id))
    end if
    return body
end function

' Optional source-matching context is shallow, bounded and never changes the media ID.
function MatchInteger(value as dynamic, minimum as integer, maximum as integer) as boolean
    numeric = GetInterface(value,"ifInt") <> invalid or GetInterface(value,"ifLongInt") <> invalid or GetInterface(value,"ifFloat") <> invalid or GetInterface(value,"ifDouble") <> invalid
    if not numeric then return false
    if value < minimum or value > maximum then return false
    return value = int(value)
end function

function MatchingContext(item as object) as object
    context = {}
    for each key in ["series_id","releaseInfo"]
        value = item[key]
        maximumLength = 512
        if key = "releaseInfo" then maximumLength = 128
        if GetInterface(value,"ifString") <> invalid
            if len(value) > 0 and len(value) <= maximumLength
                unsafe = CreateObject("roRegex","[\x00-\x1f\x7f]","")
                if not unsafe.isMatch(value) and value.trim() <> "" then context[key] = value
            end if
        end if
    end for
    for each key in ["season","episode"]
        if MatchInteger(item[key],0,100000) then context[key] = int(item[key])
    end for
    if MatchInteger(item.year,1870,2200) then context.year = int(item.year)
    if GetInterface(item.imdb_id,"ifString") <> invalid
        imdb = CreateObject("roRegex","^tt[0-9]{5,12}$","")
        if imdb.isMatch(item.imdb_id) then context.imdb_id = item.imdb_id
    end if
    tmdb = ""
    if GetInterface(item.tmdb_id,"ifString") <> invalid then tmdb = item.tmdb_id
    if MatchInteger(item.tmdb_id,1,2147483647) then tmdb = int(item.tmdb_id).toStr()
    digits = CreateObject("roRegex","^[1-9][0-9]{0,9}$","")
    if digits.isMatch(tmdb)
        ' Avoid single-precision Val rounding at the signed-32-bit boundary.
        if len(tmdb) < 10 or tmdb <= "2147483647" then context.tmdb_id = tmdb
    end if
    return context
end function

function StreamContext(item as object) as object
    context = MatchingContext(item)
    if context.year = invalid and context.releaseInfo <> invalid
        yearPattern = CreateObject("roRegex","^([0-9]{4})([^0-9]|$)","")
        matchedYear = yearPattern.match(context.releaseInfo)
        if matchedYear.count() > 1
            year = val(matchedYear[1])
            if MatchInteger(year,1870,2200) then context.year = int(year)
        end if
    end if
    if Txt(item.type) = "series"
        suffix = CreateObject("roRegex","^(.+):([0-9]+):([0-9]+)$","")
        parts = suffix.match(Txt(item.id))
        if parts.count() = 4
            derivedParent = MatchingContext({series_id:parts[1]})
            if context.series_id = invalid and derivedParent.series_id <> invalid then context.series_id = derivedParent.series_id
            if context.season = invalid and MatchInteger(val(parts[2]),0,100000) then context.season = int(val(parts[2]))
            if context.episode = invalid and MatchInteger(val(parts[3]),0,100000) then context.episode = int(val(parts[3]))
        end if
    end if
    return context
end function

function EpisodeTitle(video as object) as string
    title = Txt(video.title).trim()
    if title = "" then title = Txt(video.name).trim()
    if title = "" then title = "Episode"
    return title
end function

function OrderedEpisodes(videos as dynamic) as object
    decorated = []
    index = 0
    for each video in Bounded(videos,2000)
        if GetInterface(video,"ifAssociativeArray") <> invalid
            ' Lexical fixed-width coordinates avoid multiplication/float overflow.
            ' Original index makes ties and unknown coordinates stable independently
            ' of the native sort implementation's tie behavior.
            key = "1"
            if MatchInteger(video.season,0,100000) and MatchInteger(video.episode,0,100000)
                key = "0" + right("000000" + int(video.season).toStr(),6) + right("000000" + int(video.episode).toStr(),6)
            end if
            key += right("0000" + index.toStr(),4)
            decorated.push({orderkey:key,video:video})
        end if
        index++
    end for
    decorated.sortBy("orderkey")
    ordered = []
    for each item in decorated
        ordered.push(item.video)
    end for
    return ordered
end function

function EpisodeItem(parent as object, video as object) as object
    episode = {id:video.id,type:"series",name:parent.name,displayName:parent.name + " — " + EpisodeTitle(video),seriesName:parent.name,poster:Txt(parent.poster)}
    context = MatchingContext(video)
    parentContext = MatchingContext(parent)
    ' Identity/year belong to the parent series, coordinates to the selected video.
    for each key in ["year","releaseInfo","imdb_id","tmdb_id"]
        context.delete(key)
        if parentContext[key] <> invalid then context[key] = parentContext[key]
    end for
    context.delete("series_id")
    parentId = MatchingContext({series_id:parent.id})
    if parentId.series_id <> invalid then context.series_id = parentId.series_id
    episode.append(context)
    return episode
end function

' Labels are untrusted hints, never verification and never a reason to bypass probing.
function SourceScore(item as object, cap = 1080 as integer) as integer
    label = lcase(Txt(item.name) + " " + Txt(item.title))
    score = 0
    if m.sourceRankPatterns = invalid
        m.sourceRankPatterns = {
            hd:CreateObject("roRegex","(^|[^a-z0-9])(720p|1080p)([^a-z0-9]|$)","")
            h264:CreateObject("roRegex","(^|[^a-z0-9])(h[.]?264|x264|avc)([^a-z0-9]|$)","")
            heavy:CreateObject("roRegex","(^|[^a-z0-9])(2160p|4k|hdr(?:10\+?)?|dolby[ ._-]?vision|dv)([^a-z0-9]|$)","")
            hevc:CreateObject("roRegex","(^|[^a-z0-9])(hevc|h[.]?265|x265)([^a-z0-9]|$)","")
            cached:CreateObject("roRegex","^\[TB\+\][ \t]*Torrentio([^a-zA-Z0-9]|$)","")
            fullhd:CreateObject("roRegex","(^|[^a-z0-9])1080p([^a-z0-9]|$)","")
        }
    end if
    patterns = m.sourceRankPatterns
    if patterns.hd.isMatch(label) then score += 20
    if patterns.h264.isMatch(label) then score += 15
    if patterns.cached.isMatch(Txt(item.name).trim()) then score += 10
    if cap < 1080 and patterns.fullhd.isMatch(label) then score -= 15
    if patterns.hevc.isMatch(label) then score -= 10
    if patterns.heavy.isMatch(label) then score -= 100
    return score
end function

function CleanSourceLabel(value as string, filename = true as boolean, maxLength = 512 as integer) as string
    ' Keep Unicode words; remove controls, emoji/symbol decorations and filename separators.
    bytes = CreateObject("roByteArray")
    links = CreateObject("roRegex","https?://\S+","i")
    ' Translate regional flags before unsupported emoji filtering; never lose language information.
    flags = {"🇬🇧":" English ","🇺🇸":" English ","🇮🇹":" Italian ","🇫🇷":" French ","🇪🇸":" Spanish ","🇩🇪":" German ","🇵🇹":" Portuguese ","🇧🇷":" Portuguese ","🇷🇺":" Russian ","🇯🇵":" Japanese ","🇰🇷":" Korean ","🇨🇳":" Chinese ","🇮🇳":" Hindi ","🇳🇱":" Dutch ","🇵🇱":" Polish ","🇹🇷":" Turkish ","🇸🇦":" Arabic "}
    for each flag in flags
        if instr(1,value,flag) > 0 then value = CreateObject("roRegex",flag,"").replaceAll(value,flags[flag])
    end for
    bytes.fromAsciiString(links.replaceAll(value,"Source"))
    cleaned = CreateObject("roByteArray")
    i = 0
    while i < bytes.count()
        first = bytes[i]
        width = 1
        code = first
        if first >= 240 and first <= 244
            width = 4
            code = first mod 8
        else if first >= 224 and first <= 239
            width = 3
            code = first mod 16
        else if first >= 192 and first <= 223
            width = 2
            code = first mod 32
        end if
        if i + width > bytes.count() then exit while
        for j = 1 to width-1
            code = code*64 + (bytes[i+j] mod 64)
        end for
        drop = (code >= 126976 and code <= 131071) or (code >= 9728 and code <= 10175) or (code >= 65024 and code <= 65039) or code = 65533 or (code >= 917504 and code <= 917999) or code = 8205 or code = 8203 or (code >= 8234 and code <= 8238) or (code >= 8294 and code <= 8297)
        if code >= 127462 and code <= 127487
            ' Unknown regional flags retain their ISO country letters instead of disappearing.
            cleaned.push(32)
            cleaned.push(91)
            cleaned.push(65 + code - 127462)
            if i + 8 <= bytes.count()
                nextCode = (bytes[i+4] mod 8)*262144 + (bytes[i+5] mod 64)*4096 + (bytes[i+6] mod 64)*64 + (bytes[i+7] mod 64)
                if nextCode >= 127462 and nextCode <= 127487
                    cleaned.push(65 + nextCode - 127462)
                    width = 8
                end if
            end if
            cleaned.push(93)
            cleaned.push(32)
        else if code < 32 or (code >= 127 and code <= 159)
            cleaned.push(32)
        else if not drop
            for j = 0 to width-1
                cleaned.push(bytes[i+j])
            end for
        end if
        i += width
    end while
    text = cleaned.toAsciiString()
    if filename
        extensions = CreateObject("roRegex","[.](mkv|mp4|avi|m2ts|ts)([^a-z0-9]|$)","i")
        text = extensions.replaceAll(text," ")
        spaces = CreateObject("roRegex","[ ._]+","")
        return left(spaces.replaceAll(text," ").trim(),100)
    end if
    ' Provider guide badges are exact trailing tokens, not arbitrary Unicode
    ' letters. Preserve modifier-letter prose and these words inside sentences.
    if m.guideSuffixPattern = invalid
        m.guideSuffixPattern = CreateObject("roRegex","(^|[ ])(ᴺᵉʷ|ᴸᶦᵛᵉ|ᴴᴰ)([ ]+(ᴺᵉʷ|ᴸᶦᵛᵉ|ᴴᴰ))*[ ]*$","")
    end if
    text = m.guideSuffixPattern.replaceAll(text,"")
    spaces = CreateObject("roRegex","[ ]+","")
    return left(spaces.replaceAll(text," ").trim(),maxLength)
end function

function SourceDisplayLabel(item as object) as string
    name = Txt(item.name).split(chr(10))[0]
    name = CleanSourceLabel(name,false).split("·")[0].trim()
    if m.sourceDisplayPatterns = invalid
        m.sourceDisplayPatterns = {
            marker:CreateObject("roRegex","\[TB[+]?[ ]*\]","i")
            resolution:CreateObject("roRegex","(^|[^a-z0-9])(720p|1080p|2160p|4k)([^a-z0-9]|$)","")
            codec:CreateObject("roRegex","(^|[^a-z0-9])(h[.]?264|x264|avc|hevc|h[.]?265|x265)([^a-z0-9]|$)","")
            size:CreateObject("roRegex","(^|[^0-9])([0-9]{1,4}([.,][0-9]{1,2})?)[ ]*(GiB|MiB|GB|MB)([^a-z]|$)","i")
            group:CreateObject("roRegex","[.-]([a-z0-9-]{2,20})[.](mkv|mp4|avi|m2ts|ts)$","i")
            release:CreateObject("roRegex","(^|[^a-z0-9])(web-dl|webrip|bluray|hdtv|remux)([^a-z0-9]|$)","i")
        }
    end if
    patterns = m.sourceDisplayPatterns
    name = patterns.marker.replaceAll(name,"").trim()
    if name = "" or lcase(name) = "source"
        group = SourceGroup(item)
        if group <> "unknown" and instr(1,group,":") = 0 and instr(1,group,"/") = 0 then name = CleanSourceLabel(group,false)
    end if
    if name = "" then name = "Source"
    text = lcase(Txt(item.name) + " " + Txt(item.title))
    resolution = patterns.resolution.match(text)
    codec = patterns.codec.match(text)
    label = left(name,32)
    if resolution.count() > 2 and not patterns.resolution.isMatch(lcase(label)) then label += " · " + resolution[2]
    if codec.count() > 2 and not patterns.codec.isMatch(lcase(label)) then label += " · " + ucase(codec[2])
    ' Report only bounded hints actually present, never the full filename or the
    ' generic HTTP stream title. Size is more useful than uploader decoration.
    title = CleanSourceLabel(left(Txt(item.title),512),false)
    size = patterns.size.match(title)
    if size.count() > 4
        label += " · " + size[2] + " " + ucase(size[4])
    else
        releaseGroup = patterns.group.match(Txt(item.title).split(chr(10))[0].trim())
        if releaseGroup.count() > 1 and not patterns.codec.isMatch(lcase(releaseGroup[1]))
            label += " · " + releaseGroup[1]
        else
            release = patterns.release.match(title)
            if release.count() > 2 then label += " · " + ucase(release[2])
        end if
    end if
    languageText = CleanSourceLabel(left(Txt(item.name) + " " + Txt(item.title),512),false)
    languages = CreateObject("roRegex","(^|[^a-z])(English|Italian|French|Spanish|German|Portuguese|Russian|Japanese|Korean|Chinese|Hindi|Dutch|Polish|Turkish|Arabic|MULTI|DUAL|ENG|ITA)([^a-z]|$)","i")
    language = languages.match(languageText)
    if language.count() > 2 then label += " · " + language[2]
    return label
end function

function SourceFullDetails(item as object) as string
    text = CleanSourceLabel(Txt(item.name),false) + chr(10) + SourceAudioStatus(item) + chr(10) + chr(10)
    ' Legacy adapters may duplicate description in title. Preserve every distinct
    ' line, but do not repeat the same release block twice in the detail pane.
    seen = {}
    for each key in ["title","description","filename","language","quality","codec"]
        for each line in Txt(item[key]).split(chr(10))
            cleaned = CleanSourceLabel(line,false,4000)
            if cleaned <> "" and not seen.doesExist(cleaned)
                text += cleaned + chr(10)
                seen[cleaned] = true
            end if
        end for
    end for
    ' Dedicated metadata fields need not also appear in a provider's prose.
    for each language in Bounded(item.reported_languages,16)
        value = CleanSourceLabel(left(Txt(language),32),false)
        if value <> "" then text += "Reported language: " + value + chr(10)
    end for
    size = item.size_bytes
    if GetInterface(size,"ifInt") <> invalid or GetInterface(size,"ifLongInt") <> invalid or GetInterface(size,"ifFloat") <> invalid or GetInterface(size,"ifDouble") <> invalid
        if size > 0 and size <= 1125899906842624#
            units = ["bytes","KiB","MiB","GiB","TiB","PiB"]
            unit = 0
            while size >= 1024 and unit < 5
                size = size / 1024#
                unit++
            end while
            text += "Reported size: " + Txt(int(size*100 + 0.5)/100#) + " " + units[unit] + chr(10)
        end if
    end if
    return left(text,6000)
end function

function DistinctSourceLabels(values as object) as object
    counts = {}
    ordinals = {}
    for each item in Bounded(values,80)
        label = Txt(item.displayName)
        if counts[label] = invalid then counts[label] = 0
        counts[label]++
    end for
    output = []
    for each item in Bounded(values,80)
        copy = {}
        copy.append(item)
        label = Txt(item.displayName)
        if counts[label] > 1
            if ordinals[label] = invalid then ordinals[label] = 0
            ordinals[label]++
            copy.displayName = label + " · " + ordinals[label].toStr()
        end if
        output.push(copy)
    end for
    return output
end function

function SourceGroup(item as object) as string
    return Txt(item.source,Txt(item.addon_id,"unknown"))
end function

function FairSources(existing as object, incoming as object, pinned = "" as string, cap = 1080 as integer) as object
    output = []
    groups = {}
    ids = {}
    scores = {}
    all = []
    for each item in existing
        all.push(item)
    end for
    for each item in incoming
        all.push(item)
    end for
    for each item in all
        id = Txt(item.id)
        if id <> "" and not ids.doesExist(id)
            group = SourceGroup(item)
            if not groups.doesExist(group) and groups.count() < 8 then groups[group] = []
            if groups.doesExist(group)
                scores[id] = SourceScore(item,cap)
                bucket = groups[group]
                if bucket.count() < 10
                    bucket.push(item)
                else
                    worst = -1
                    for i = 0 to bucket.count()-1
                        if Txt(bucket[i].id) <> pinned
                            if worst < 0
                                worst = i
                            else if scores[Txt(bucket[i].id)] < scores[Txt(bucket[worst].id)]
                                worst = i
                            end if
                        end if
                    end for
                    if worst >= 0
                        if id = pinned or scores[id] > scores[Txt(bucket[worst].id)] then bucket[worst] = item
                    end if
                end if
                ids[id] = true
            end if
        end if
    end for
    ' Round-robin exposes every admitted provider before its second result.
    for column = 0 to 9
        for each group in groups
            bucket = groups[group]
            if column < bucket.count() then output.push(bucket[column])
        end for
    end for
    return output
end function

function FarBeforeEnd(position as float, duration as float) as boolean
    return duration > 0 and position >= 0 and duration-position > 60 and position < duration * 0.95
end function

function SourceIdsExpired(issued as dynamic, now as integer) as boolean
    if issued = invalid then return false
    return issued > 0 and now - issued >= 1500
end function

' Presentation-only: never modify the opaque source or interpret language hints
' as probed audio. Provider and quality have separate bounded space from languages.
function SourceCardTitle(item as object) as string
    provider = CleanSourceLabel(Txt(item.name,Txt(item.source,"Source")),false,256).split("·")[0].trim()
    provider = CreateObject("roRegex","\[TB[+]?[ ]*\]","i").replaceAll(provider,"").trim()
    if provider = "" then provider = "Source"
    if len(provider) > 22 then provider = left(provider,21) + "…"
    text = lcase(left(Txt(item.name),256) + " " + left(Txt(item.title),1024))
    quality = ""
    resolutionPattern = CreateObject("roRegex","(^|[^a-z0-9])(720p|1080p|2160p|4k)([^a-z0-9]|$)","")
    codecPattern = CreateObject("roRegex","(^|[^a-z0-9])(h[.]?264|x264|avc|hevc|h[.]?265|x265)([^a-z0-9]|$)","")
    resolution = resolutionPattern.match(text)
    codec = codecPattern.match(text)
    ' Check the visible bounded label, not the original provider: a truncated
    ' quality token still needs its complete suffix.
    if resolution.count() > 2 and not resolutionPattern.isMatch(lcase(provider)) then quality = resolution[2]
    if codec.count() > 2 and not codecPattern.isMatch(lcase(provider))
        if quality <> "" then quality += " · "
        quality += ucase(codec[2])
    end if
    if quality <> "" then return provider + " · " + quality
    return provider
end function

' Return compact words, without the fixed UI prefix. At most two names + count;
' explicit reported_languages wins over filename/name hints, even if unknown.
function SourceAudioStatus(item as object) as string
    languages = SourceReportedLanguages(item)
    if languages = "Unknown" then return "Audio · Language unknown"
    return "Audio · " + languages + " (reported)"
end function

function SourceReportedLanguages(item as object) as string
    aliases = {
        english:"English",eng:"English",en:"English",italian:"Italian",ita:"Italian",it:"Italian",
        french:"French",fra:"French",fre:"French",fr:"French",spanish:"Spanish",spa:"Spanish",es:"Spanish",
        german:"German",ger:"German",deu:"German",de:"German",portuguese:"Portuguese",por:"Portuguese",pt:"Portuguese",
        russian:"Russian",rus:"Russian",ru:"Russian",japanese:"Japanese",jpn:"Japanese",ja:"Japanese",
        korean:"Korean",kor:"Korean",ko:"Korean",chinese:"Chinese",chi:"Chinese",zho:"Chinese",zh:"Chinese",
        hindi:"Hindi",hin:"Hindi",hi:"Hindi",dutch:"Dutch",dut:"Dutch",nld:"Dutch",nl:"Dutch",
        polish:"Polish",pol:"Polish",pl:"Polish",turkish:"Turkish",tur:"Turkish",tr:"Turkish",
        arabic:"Arabic",ara:"Arabic",ar:"Arabic",swedish:"Swedish",swe:"Swedish",sv:"Swedish",
        danish:"Danish",dan:"Danish",da:"Danish",norwegian:"Norwegian",nor:"Norwegian",no:"Norwegian",
        finnish:"Finnish",fin:"Finnish",fi:"Finnish",ukrainian:"Ukrainian",ukr:"Ukrainian",uk:"Ukrainian",
        multi:"Multiple",dual:"Dual",unknown:"Unknown",und:"Unknown"
    }
    reported = Bounded(item.reported_languages,16)
    explicit = reported.count() > 0
    if not explicit then reported = [left(Txt(item.name),256) + " " + left(Txt(item.title),1024)]
    names = []
    seen = {}
    for each hint in reported
        normalized = lcase(CleanSourceLabel(Txt(hint),false,1280))
        tokens = CreateObject("roRegex","[^a-z]+","").replaceAll(normalized," ").split(" ")
        for each token in tokens
            word = aliases[token]
            ' Two-letter words in release titles (It, No, Hi...) are ambiguous.
            if not explicit and len(token) = 2 then word = invalid
            if word <> invalid
                if not seen.doesExist(word)
                    seen[word] = true
                    names.push(word)
                end if
            end if
        end for
    end for
    if names.count() = 0 then return "Unknown"
    label = names[0]
    if names.count() > 1 then label += " / " + names[1]
    if names.count() > 2 then label += " +" + (names.count()-2).toStr()
    return label
end function

' Some Roku firmware resumes a paused native seek despite autoplayAfterSeek.
' Reassert pause once decoding resumes, then release the intent for normal Play.
function DirectSeekPause(video as object, pending as boolean) as boolean
    if not pending then return false
    if video.state = "playing"
        video.control = "pause"
        return false
    end if
    if video.state = "paused" then return false
    return true
end function

' Read the installed package, so Settings cannot drift from release versions.
function InstalledAppVersion() as string
    fields = {}
    for each line in ReadAsciiFile("pkg:/manifest").split(chr(10))
        pair = line.split("=")
        if pair.count() = 2 then fields[pair[0].trim()] = pair[1].trim()
    end for
    for each key in ["major_version","minor_version","build_version"]
        if Txt(fields[key]) = "" then return "Unknown"
    end for
    return fields.major_version + "." + fields.minor_version + "." + fields.build_version
end function

' Playback lifecycle work is independent of progress/heartbeat writes. Account,
' preference and other mutations retain ordering; cancellation can always run.
function PlaybackRequestsConflict(a as object, b as object) as boolean
    if a.method = "GET" or b.method = "GET" then return false
    first = Txt(a.tag).split("|")[0]
    second = Txt(b.tag).split("|")[0]
    if first = "cleanupstartup" or second = "cleanupstartup" then return false
    aPlayback = first = "playback" or first = "seekplayback" or first = "cleanup"
    bPlayback = second = "playback" or second = "seekplayback" or second = "cleanup"
    aProgress = first = "sideprogress" or first = "sideheartbeat" or first = "siderestorequeue"
    bProgress = second = "sideprogress" or second = "sideheartbeat" or second = "siderestorequeue"
    return not ((aPlayback and bProgress) or (bPlayback and aProgress))
end function
