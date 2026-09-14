' Presentation adapters only. These never select, rank or rewrite a playback source.
function UiProgressFraction(item as object) as float
    if item.position = invalid or item.duration = invalid then return -1.0
    if item.duration <= 0 or item.position <= 0 then return -1.0
    fraction = item.position / item.duration
    if fraction > 1 then fraction = 1
    return fraction
end function

function PresentationMetadataId(item as object) as string
    ' Details/artwork use the supplied parent identity, not an episode playback ID.
    ' Never split or guess opaque identifiers, and never mutate the original item.
    if Txt(item.type) = "series"
        context = MatchingContext(item)
        if Txt(context.series_id) <> "" then return context.series_id
    end if
    return Txt(item.id)
end function

function PresentationBackdrop(item as object) as string
    for each field in ["backdrop","background"]
        uri = Txt(item[field])
        if uri <> "" and uri <> Txt(item.poster) then return PresentationLandscapeUrl(uri)
    end for
    return ""
end function

function PresentationContext(item as object) as string
    status = Txt(item.queue_status)
    if status = "caught_up" then return "You're caught up"
    if status = "upcoming" then return "Next episode not released"
    if status = "pending" or status = "unavailable" then return "Find next episode"
    if status = "next" then return "Up next · S"+Txt(item.season)+" E"+Txt(item.episode)
    values = []
    context = StreamContext(item)
    if context.season <> invalid then values.push("Season " + Txt(context.season))
    if context.episode <> invalid then values.push("Episode " + Txt(context.episode))
    title = Txt(item.episodeTitle)
    if title <> "" then values.push(title)
    if item.position <> invalid
        if item.position > 0 then values.push("Resume at " + PlayerTime(item.position))
    end if
    return values.join("  ·  ")
end function

function PresentationFacts(item as object) as string
    values = []
    kind = Txt(item.type)
    if kind = "movie" then values.push("MOVIE")
    if kind = "series" then values.push("SERIES")
    if kind = "live" then values.push("LIVE")
    year = Txt(item.releaseInfo,Txt(item.year))
    if year <> "" then values.push(year)
    rating = Txt(item.imdbRating)
    if rating <> "" then values.push("IMDb " + rating)
    runtime = Txt(item.runtime)
    if runtime <> "" then values.push(runtime)
    genres = []
    for each genre in Bounded(item.genres,3)
        if Txt(genre) <> "" then genres.push(Txt(genre))
    end for
    if genres.count() > 0 then values.push(genres.join(" / "))
    return values.join("  ·  ")
end function

sub UiCardContent(node as object, item as object)
    node.title = Txt(item.name,Txt(item.title,"Untitled"))
    art = PresentationBackdrop(item)
    kind = "landscape"
    if art = "" then art = Txt(item.thumbnail)
    if art = "" and Txt(item.posterShape) = "landscape" then art = Txt(item.poster)
    path = "/api/meta/" + Enc(Txt(item.type,"movie")) + "/" + Enc(PresentationMetadataId(item))
    if art = "" and m.uiLandscapeCache <> invalid
        if m.uiLandscapeCache[path] <> invalid then art = m.uiLandscapeCache[path]
    end if
    if Txt(item.type) = "live"
        art = Txt(item.logo,Txt(item.poster))
        kind = "logo"
    end if
    if Txt(item.posterShape) = "landscape" then kind = "landscape"
    node.HDPosterUrl = art
    subtitle = PresentationFacts(item)
    context = PresentationContext(item)
    if context <> "" then subtitle = context
    node.addFields({metadataPath:path,metadataId:PresentationMetadataId(item),artworkKind:kind,mediaType:Txt(item.type),subtitle:subtitle,progressFraction:UiProgressFraction(item),badge:"",uiOwnerFocused:false})
    node.description = Txt(item.description,Txt(item.overview))
end sub

function EpisodePresentationItem(parent as object, video as object) as object
    item = EpisodeItem(parent,video)
    for each key in ["position","duration","source_addon_id","source_name","source_fingerprint"]
        if video[key] <> invalid then item[key] = video[key]
    end for
    if video.watched = true then item.position = 0
    item.episodeTitle = EpisodeTitle(video)
    item.thumbnail = Txt(video.thumbnail,Txt(video.image))
    item.background = PresentationBackdrop(parent)
    item.description = Txt(video.overview,Txt(video.description))
    return item
end function

function OriginalSourceName(item as object) as string
    name = Txt(item.name)
    if name = "" then name = Txt(item.source,"Source")
    return name
end function

function SourceOriginalTitle(item as object) as string
    title = Txt(item.title)
    if title = "" then title = Txt(item.description)
    if title = "" then title = Txt(item.filename)
    return title
end function

function OriginalSourceDetails(item as object) as string
    text = OriginalSourceName(item)
    title = SourceOriginalTitle(item)
    if title <> "" then text += chr(10) + chr(10) + title
    description = Txt(item.description)
    if description <> "" and description <> title then text += chr(10) + chr(10) + description
    return text
end function

function UiIsFavorite(item as object) as boolean
    values = m.liveFavoriteItems
    if values = invalid and m.homeData <> invalid then values = m.homeData[4]
    for each favorite in Bounded(values,10000)
        if Txt(favorite.id) = Txt(item.id) and Txt(favorite.type) = Txt(item.type) then return true
    end for
    return false
end function

function UiCatalogRequired(catalog as dynamic, name as string) as boolean
    if catalog = invalid then return false
    for each extra in Bounded(catalog.extra,32)
        if Txt(extra.name) = name and extra.required = true then return true
    end for
    return false
end function

function LiveOnlyItems(items as dynamic) as object
    result = []
    for each item in Bounded(items,500)
        if Txt(item.type) = "live" then result.push(item)
    end for
    return result
end function

function OnDemandItems(items as dynamic) as object
    result = []
    for each item in Bounded(items,500)
        if Txt(item.type) <> "live" then result.push(item)
    end for
    return result
end function

function ContinueWatchingItems(items as dynamic) as object
    result = []
    seen = {}
    for each item in OnDemandItems(items)
        id = Txt(item.id)
        if item.type = "series"
            id = PresentationMetadataId(item)
            legacy = CreateObject("roRegex","^(tt[0-9]+):[0-9]+:[0-9]+$","")
            parts = legacy.match(id)
            if parts.count() > 1 then id = parts[1]
        end if
        key = Txt(item.type) + "|" + id
        if not seen.doesExist(key)
            seen[key] = true
            if Txt(item.queue_status) <> ""
                result.push(item)
            else if item.position <> invalid
                if item.position >= 0 and (item.type = "series" or UiProgressFraction(item) < 0.95) then result.push(item)
            end if
        end if
    end for
    return result
end function

function FavoriteArtwork(item as object) as string
    poster = Txt(item.poster)
    if poster = "" then poster = Txt(item.logo)
    return poster
end function

function PresentationLandscapeUrl(uri as string) as string
    ' Request a full-HD-ready backdrop from TMDB, preserving the actual image identity.
    sizes = CreateObject("roRegex","^https://image\.tmdb\.org/t/p/(w[0-9]+|original)/","")
    if sizes.isMatch(uri) then return sizes.replace(uri,"https://image.tmdb.org/t/p/w1280/")
    return uri
end function

function SourceProviderName(item as object) as string
    name = Txt(item.source_name,Txt(item.addon_name))
    if name = "" then name = OriginalSourceName(item)
    return name
end function

function PresentationCredits(item as object) as string
    lines = []
    for each field in ["director","cast"]
        names = []
        if GetInterface(item[field],"ifArray") <> invalid
            for each name in Bounded(item[field],4)
                if Txt(name) <> "" then names.push(Txt(name))
            end for
        else if Txt(item[field]) <> ""
            names.push(Txt(item[field]))
        end if
        if names.count() > 0
            prefix = "Starring  "
            if field = "director" then prefix = "Directed by  "
            lines.push(prefix + names.join(", "))
        end if
    end for
    return lines.join(chr(10))
end function

function PresentationFullDetails(item as object) as string
    text = PresentationFacts(item) + chr(10) + chr(10) + Txt(item.description,Txt(item.overview))
    credits = PresentationCredits(item)
    if credits <> "" then text += chr(10) + chr(10) + credits
    return text
end function

function ReadableSourceText(value as string) as string
    output = []
    symbols = {"📄":"File: ","📁":"File: ","💾":"Size: ","👤":"Peers: ","👥":"Peers: ","🌐":"Languages: ","🔊":"Audio: ","🎧":"Audio: ","💬":"Subtitles: ","⚡":"Cached ","✅":"Available ","❌":"Unavailable "}
    for each symbol in symbols
        value = CreateObject("roRegex",symbol,"").replaceAll(value,symbols[symbol])
    end for
    for each line in value.split(chr(10))
        clean = CleanSourceLabel(line,false,2048)
        if clean <> "" then output.push(clean)
    end for
    return output.join(chr(10))
end function
function SourceLanguageScore(item as object, language = "en" as string) as integer
    if language = "en" and item.audioEvidenceScore <> invalid then return item.audioEvidenceScore
    languages = {en:"english|eng|en",es:"spanish|spa|es",fr:"french|fre|fra|fr",de:"german|ger|deu|de",it:"italian|ita|it",pt:"portuguese|por|pt",ja:"japanese|jpn|ja",ko:"korean|kor|ko",zh:"chinese|zho|chi|zh",hi:"hindi|hin|hi",ar:"arabic|ara|ar"}
    pattern = Txt(languages[language],"english|eng|en")
    word = "(^|[^a-z])("+pattern+")([^a-z]|$)"
    reported = false
    for each value in Bounded(item.reported_languages,16)
        if CreateObject("roRegex","^("+pattern+")([-_].*)?$","i").isMatch(Txt(value)) then reported = true
    end for
    text = ReadableSourceText(Txt(item.name)+chr(10)+SourceCardText(item))
    text = CreateObject("roRegex","[|;]","").replaceAll(text,chr(10))
    mentioned = false : explicit = false : dubbed = false : multi = false
    for each line in text.split(chr(10))
        subtitles = CreateObject("roRegex","(^|[^a-z])(subtitles?|subs?|captions?)([^a-z]|$)","i").isMatch(line)
        audio = CreateObject("roRegex","(^|[^a-z])(audio|dubbed|dub)([^a-z]|$)","i").isMatch(line)
        ' A subtitle-only clause is not spoken-language evidence. Mixed clauses
        ' retain explicit audio evidence before the subtitle annotation.
        if not subtitles or audio
            if subtitles then line = CreateObject("roRegex","("+pattern+")[ ._:-]+(subtitles?|subs?|captions?)","i").replaceAll(line,"")
            if subtitles then line = CreateObject("roRegex","(^|[^a-z])(subtitles?|subs?|captions?)([^a-z]|$).*","i").replace(line,"")
            if CreateObject("roRegex",word,"i").isMatch(line) then mentioned = true
            if CreateObject("roRegex","(^|[^a-z])(("+pattern+")[ ._:-]+(audio|dubbed|dub)|(audio|dubbed|dub)[ ._:-]+("+pattern+"))([^a-z]|$)","i").isMatch(line) then explicit = true
            if language = "en"
                if CreateObject("roRegex","(^|[^a-z])(dubbed|dub)([^a-z]|$)","i").isMatch(line) then dubbed = true
                if CreateObject("roRegex","(^|[^a-z])(dual[ ._-]?audio|multi[ ._-]?audio)([^a-z]|$)","i").isMatch(line) then multi = true
            end if
        end if
    end for
    ' Independent evidence adds weight once, never once per repeated token.
    score = 0
    if reported then score += 1
    if mentioned then score += 1
    if multi then score += 2
    if dubbed then score += 3
    if explicit then score += 4
    if score > 9 then score = 9
    return score
end function

function SourceAudioHint(item as object) as integer
    score = SourceLanguageScore(item)
    if score >= 4 then return 0
    if score >= 2 then return 1
    if score = 1 then return 3
    return 2
end function
function SourceCardText(item as object) as string
    values = []
    for each value in [Txt(item.title),Txt(item.description),Txt(item.filename)]
        if value <> "" and instr(1,values.join(chr(10)),value)=0 then values.push(value)
    end for
    return ReadableSourceText(values.join(chr(10)))
end function
function SourceBadges(item as object, preference as dynamic) as string
    badges = []
    if item.bestMatch = true then badges.push("BEST MATCH")
    if item.likelyDirect = true then badges.push("LIKELY COMPATIBLE")
    if SourceMatchesPreference(item,preference) then badges.push("LAST PLAYED")
    hint = SourceAudioHint(item)
    if hint = 0 then badges.push("STRONG AUDIO HINT")
    if hint = 1 then badges.push("POSSIBLE AUDIO MATCH")
    if hint = 3 then badges.push("ENGLISH TEXT HINT")
    if badges.count() = 0 then badges.push("AUDIO NOT IDENTIFIED")
    return badges.join("   ·   ")
end function

' Recommendation is a hint until the server inspects the actual media. No
' filename, flag, or MULTI tag can grant verified direct-play eligibility.
function SourceMatch(item as object, caps as dynamic, prefs as dynamic) as object
    height = 1080
    hevc = false
    if GetInterface(caps,"ifAssociativeArray") <> invalid
        if caps.max_height <> invalid then height = caps.max_height
        hevc = caps.hevc_sdr = true
    end if
    language = "en"
    if GetInterface(prefs,"ifAssociativeArray") <> invalid
        language = Txt(prefs.audio_language,"en")
        quality = Txt(prefs.quality)
        if quality = "720p" and height > 720 then height = 720
        if quality = "1080p" and height > 1080 then height = 1080
        if quality = "480p" and height > 480 then height = 480
    end if
    text = lcase(ReadableSourceText(Txt(item.name)+chr(10)+SourceCardText(item)))
    audioScore = SourceLanguageScore(item,language)
    resolution = 0
    for each value in [480,720,1080,2160]
        if instr(1,text,value.toStr()+"p") > 0 then resolution = value
    end for
    if instr(1,text,"4k") > 0 then resolution = 2160
    h264 = CreateObject("roRegex","(^|[^a-z0-9])(h[.]?264|x264|avc)([^a-z0-9]|$)","").isMatch(text)
    h265 = CreateObject("roRegex","(^|[^a-z0-9])(h[.]?265|x265|hevc)([^a-z0-9]|$)","").isMatch(text)
    heavy = CreateObject("roRegex","(^|[^a-z0-9])(hdr|hdr10|dv|10bit|10-bit|hi10p|av1)([^a-z0-9]|$)","").isMatch(text)
    likely = resolution > 0 and resolution <= height and (h264 or (h265 and hevc)) and not heavy
    rank = (9-audioScore)*10+5
    if likely then rank = (9-audioScore)*10+1
    if likely and resolution = height then rank = (9-audioScore)*10
    return {rank:rank,likely:likely,best:likely and audioScore >= 4 and resolution = height}
end function
