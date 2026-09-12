' Pure layout routing: paging/actions stay in the same ordered content array.
function UsesPosterGrid(mode as string, mediaType as dynamic, values as object) as boolean
    if mode <> "browse" and mode <> "collection" and mode <> "searchall" then return false
    if mediaType = "live" and mode = "browse" then return false
    if mode = "browse" and (mediaType = "movie" or mediaType = "series") and values.count() > 0 then return true
    hasPoster = false
    for each item in values
        if item.type = "movie" or item.type = "series" then hasPoster = true
    end for
    return hasPoster
end function

function RestoreCardIndex(index as dynamic, count as integer) as integer
    if count <= 0 then return 0
    if index = invalid or index < 0 then return 0
    if index >= count then return count - 1
    return index
end function

function ProfileCollectionPath(profile as string, collection as string) as string
    resource = collection
    if collection = "progress" then resource = "continue"
    if collection = "recentlive" then resource = "progress"
    return "/api/profiles/" + Enc(profile) + "/" + resource
end function

function DiscoverTypeName(kind as string) as string
    names = {movie:"Movies",series:"Series",anime:"Anime", "anime.movie":"Anime movies", "anime.series":"Anime series",collection:"Collections"}
    return Txt(names[kind],kind)
end function

function DiscoverGenreLabel(catalog as object) as string
    name = lcase(Txt(catalog.name))
    if instr(1,name,"year") > 0 then return "Years"
    if instr(1,name,"language") > 0 then return "Languages"
    return "Genres"
end function

function DiscoverExtraLabel(name as string) as string
    if name = "calendarVideosIds" then return "Calendar video IDs"
    if name = "search" then return "Search"
    return name
end function

function DiscoverMissingOption(catalog as object, search as dynamic, genre as dynamic, values as dynamic) as string
    for each extra in Bounded(catalog.extra,16)
        if extra.required = true and extra.name <> "skip"
            value = ""
            if extra.name = "search"
                value = Txt(search)
            else if extra.name = "genre"
                value = Txt(genre)
            else if values <> invalid
                value = Txt(values[extra.name])
            end if
            if value.trim() = "" then return DiscoverExtraLabel(extra.name)
        end if
    end for
    return ""
end function
