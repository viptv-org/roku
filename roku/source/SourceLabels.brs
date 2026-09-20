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

' Canonical provider key: grouping and provider filtering share this one definition.
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
