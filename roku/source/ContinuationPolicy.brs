' Fresh next-episode source selection. Exact same-episode resume remains separate.
function ContinuationQuality(source as object) as string
    label = Txt(source.filename)+" "+Txt(source.name)+" "+Txt(source.title)
    quality = CreateObject("roRegex","(^|[^a-z0-9])(2160p|1080p|720p|480p|4k)([^a-z0-9]|$)","i").match(label)
    if quality.count() > 2 then return lcase(quality[2])
    return ""
end function

function BestContinuationSource(sources as object, preference as object, caps = invalid as dynamic, prefs = invalid as dynamic) as dynamic
    provider = Txt(preference.source_addon_id)
    if left(provider,5) = "iptv:"
        for each source in sources
            if Txt(source.source_addon_id) = provider then return source
        end for
        return invalid
    end if
    winner = invalid
    best = 1000
    for each source in sources
        if left(Txt(source.source_addon_id),6) = "addon:"
            rank = SourceMatch(source,caps,prefs).rank
            if rank < best
                winner = source
                best = rank
            end if
        end if
    end for
    return winner
end function

function NearEpisodeEnd(position as dynamic, duration as dynamic) as boolean
    if position = invalid or duration = invalid then return false
    return duration > 10 and position >= duration-10
end function

function ContinuationAudio(source as object) as string
    audio = SourceReportedLanguages(source)
    if audio = "Unknown" and SourceAudioHint(source) = 1 then return "Dubbing / multiple audio"
    return audio
end function
