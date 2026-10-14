' Draft selection belongs to the sheet until Apply; Cancel never mutates the query.
function ChoiceSelectionLimit(value as dynamic) as integer
    if value = invalid then return 64
    if value < 0 then return 0
    if value > 64 then return 64
    return int(value)
end function

function ChoiceHasValue(values as object, value as string) as boolean
    for each selected in values
        if selected = value then return true
    end for
    return false
end function

function ChoiceToggle(values as object, value as string, maximum as integer) as object
    output = []
    exists = ChoiceHasValue(values,value)
    for each selected in values
        if selected <> value then output.push(selected)
    end for
    if not exists and output.count() < maximum then output.push(value)
    return output
end function

function ChoiceInitialSelection(items as object, selected as dynamic, maximum as integer) as object
    output = []
    for each item in items
        value = Txt(item.value)
        if value <> "" and ChoiceHasValue(Bounded(selected,64),value) and not ChoiceHasValue(output,value)
            if output.count() < maximum then output.push(value)
        end if
    end for
    return output
end function
