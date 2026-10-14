' Presentation projection only; host identities and parent coordinates remain opaque.
function EngineCard(card as dynamic) as dynamic
    if not AccountIsObject(card) or not AccountIsObject(card.identity) then return invalid
    identity = card.identity
    kind = Txt(identity.kind)
    if kind = "channel" or kind = "tv" then kind = "live"
    if kind <> "movie" and kind <> "series" and kind <> "live" then return invalid
    if Txt(identity.id) = "" or Txt(card.title) = "" then return invalid
    item = {id:identity.id,type:kind,name:card.title,title:card.title,genres:[],engine_card:card,engine_identity:identity,engine_provider_id:card.provider_id,category:card.category}
    for each pair in [["poster","poster"],["landscape","background"],["logo","logo"],["description","description"]]
        if GetInterface(card[pair[0]],"ifString") <> invalid then item[pair[1]] = card[pair[0]]
    end for
    if AccountIsObject(card.metadata)
        metadata = card.metadata
        if EngineIsNumber(metadata.year) then item.year = metadata.year
        if EngineIsNumber(metadata.runtime_minutes) then item.runtime = metadata.runtime_minutes.toStr() + "m"
        if EngineIsNumber(metadata.rating) then item.imdbRating = metadata.rating.toStr()
        if EngineIsArray(metadata.genres) then item.genres = metadata.genres
    end if
    if AccountIsObject(identity.episode)
        item.episode = identity.episode.episode
        item.season = identity.episode.season
        item.episodeTitle = card.title
    end if
    if AccountIsObject(card.parent_identity)
        item.series_id = card.parent_identity.id
        item.engine_parent_identity = card.parent_identity
    end if
    return item
end function

function EngineCards(cards as dynamic) as object
    output = []
    if not EngineIsArray(cards) then return output
    for each card in cards
        item = EngineCard(card)
        if item <> invalid then output.push(item)
    end for
    return output
end function

function EngineSameIdentity(a as dynamic, b as dynamic) as boolean
    if not AccountIsObject(a) or not AccountIsObject(b) then return false
    for each key in ["kind","id","edition"]
        if Txt(a[key]) <> Txt(b[key]) then return false
    end for
    if AccountIsObject(a.episode) <> AccountIsObject(b.episode) then return false
    if AccountIsObject(a.episode)
        for each key in ["order","season","episode"]
            if Txt(a.episode[key]) <> Txt(b.episode[key]) then return false
        end for
    end if
    return true
end function

function EngineContinuation(entry as dynamic) as dynamic
    if not AccountIsObject(entry) then return invalid
    item = EngineCard(entry.card)
    if item = invalid then return invalid
    item.queue_status = lcase(Txt(entry.status))
    if entry.status = "CaughtUp" then item.queue_status = "caught_up"
    record = entry.record
    if entry.status = "Resume" and AccountIsObject(record)
        if EngineSameIdentity(item.engine_identity,record.identity)
            if EngineIsNumber(record.position_millis) then item.position = record.position_millis / 1000.0
            if EngineIsNumber(record.duration_millis) then item.duration = record.duration_millis / 1000.0
            item.watched = record.completed_at_millis <> invalid
            item.resume_active = true
        end if
    end if
    if entry.status = "Next" and AccountIsObject(record)
        if AccountIsObject(record.presentation) then item.previous_episode = EngineCard(record.presentation)
    end if
    return item
end function

function EngineIsArray(value as dynamic) as boolean
    return GetInterface(value,"ifArray") <> invalid
end function

function EngineIsNumber(value as dynamic) as boolean
    return GetInterface(value,"ifInt") <> invalid or GetInterface(value,"ifLongInt") <> invalid or GetInterface(value,"ifFloat") <> invalid or GetInterface(value,"ifDouble") <> invalid
end function
