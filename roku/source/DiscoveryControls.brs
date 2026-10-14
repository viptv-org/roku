' Host-authored discovery descriptors; never infer capabilities from Home cards.
function DiscoveryTypeLabel(kind as string) as string
    labels = {movie:"Movies",series:"Series",anime:"Anime","anime.movie":"Anime movies","anime.series":"Anime series"}
    return Txt(labels[kind],kind)
end function

function DiscoveryControlValues(control as object, search as dynamic, genre as dynamic, extras as dynamic, vectors as dynamic) as object
    if control.kind = "MultiChoice"
        if vectors <> invalid then return Bounded(vectors[control.id],64)
        return []
    end if
    value = ""
    if control.id = "search" then value = Txt(search)
    if control.id = "genre" then value = Txt(genre)
    if control.id <> "search" and control.id <> "genre" and extras <> invalid then value = Txt(extras[control.id])
    if value.trim() = "" then return []
    return [value]
end function

function DiscoveryControlLabel(control as object, currentValues as object) as string
    if currentValues.count() = 0
        if control.required = true then return "Required"
        return "Default"
    end if
    if control.kind = "MultiChoice" then return currentValues.count().toStr()+" selected"
    if control.kind = "Toggle"
        if currentValues[0] = "true" then return "On"
        return "Off"
    end if
    for each choice in Bounded(control.choices,2048)
        if Txt(choice.value) = currentValues[0] then return Txt(choice.label,currentValues[0])
    end for
    return currentValues[0]
end function

function DiscoveryMissingControl(catalog as object, search as dynamic, genre as dynamic, extras as dynamic, vectors as dynamic) as string
    for each control in Bounded(catalog.controls,64)
        if control.id <> "type" and control.id <> "catalog" and control.id <> "skip" and control.maximum_selections <> 0
            currentValues = DiscoveryControlValues(control,search,genre,extras,vectors)
            if control.required = true and currentValues.count() = 0 then return Txt(control.label,control.id)
            if control.maximum_selections <> invalid
                if currentValues.count() > control.maximum_selections then return Txt(control.label,control.id)
            end if
        end if
    end for
    return ""
end function

function DiscoveryQueryValues(vectors as dynamic) as object
    output = []
    if GetInterface(vectors,"ifAssociativeArray") = invalid then return output
    for each name in vectors
        values = Bounded(vectors[name],64)
        if values.count() > 0 then output.push({id:name,values:values})
    end for
    return output
end function
