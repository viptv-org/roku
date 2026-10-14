function EngineLivePage(value as dynamic, offset as integer, limit as integer, categories as boolean) as dynamic
    if not AccountIsObject(value) or not EngineIsArray(value.channels) or not EngineIsArray(value.groups) then return invalid
    connection = invalid
    if value.channels.count() > 0 then connection = value.channels[0].connection_id
    if connection = invalid and EngineIsArray(value.connections)
        if value.connections.count() > 0 then connection = value.connections[0].id
    end if
    items = []
    nextCursor = value.next_cursor
    if categories
        last = offset+limit-1
        if last >= value.groups.count() then last = value.groups.count()-1
        for i = offset to last
            group = value.groups[i]
            items.push({id:group.id,name:group.label})
        end for
        nextCursor = invalid
        if offset+limit < value.groups.count() then nextCursor = (offset+limit).toStr()
    else
        for each channel in value.channels
            item = EngineCard(channel.card)
            if item = invalid or item.id <> channel.id then return invalid
            item.type = "live"
            item.category = channel.group_name
            item.category_id = channel.group_id
            items.push(item)
        end for
    end if
    previous = invalid
    if offset > 0
        previousOffset = offset-limit
        if previousOffset < 0 then previousOffset = 0
        previous = previousOffset.toStr()
    end if
    ' This contract does not advertise a playlist generation; preserve unknown.
    return {catalog_id:connection,generation:invalid,items:items,next_cursor:nextCursor,previous_cursor:previous}
end function

function EngineLiveGuide(value as dynamic) as dynamic
    if not AccountIsObject(value) or not EngineIsArray(value.programs) then return invalid
    programs = []
    for each program in value.programs
        if EngineIsNumber(program.start_millis) and EngineIsNumber(program.end_millis)
            programs.push({title:program.title,start:program.start_millis/1000.0#,end:program.end_millis/1000.0#,description:program.description})
        end if
    end for
    return {programs:programs}
end function
