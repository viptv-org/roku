' Half-open UTC intervals keep adjacent programmes and regional feeds distinct.
function EpgCells(programmes as dynamic, startAt as integer, finishAt as integer) as object
    entries = []
    for each p in Bounded(programmes,100)
        if GetInterface(p,"ifAssociativeArray") <> invalid
            if p.start <> invalid and p.end <> invalid
                if p.end > p.start and p.end > startAt and p.start < finishAt then entries.push(p)
            end if
        end if
    end for
    entries.sortBy("start")
    cells = []
    cursor = startAt
    for each p in entries
        if cells.count() >= 32 then exit for
        first = p.start
        last = p.end
        if first < cursor then first = cursor
        if last > finishAt then last = finishAt
        if first > cursor then cells.push({start:cursor,end:first,title:"No schedule available",missing:true})
        if last > first
            cell = {start:first,end:last,title:Txt(p.title,"Untitled programme"),missing:false,programme:p}
            cells.push(cell)
            cursor = last
        end if
    end for
    if cursor < finishAt then cells.push({start:cursor,end:finishAt,title:"No schedule available",missing:true})
    return cells
end function

function EpgCellAt(cells as object, at as integer) as integer
    for i = 0 to cells.count()-1
        if cells[i].start <= at and cells[i].end > at then return i
    end for
    return 0
end function

function EpgGeometry(cell as object, startAt as integer, span as integer, width as integer) as object
    x = int((cell.start-startAt)*1.0/span*width)
    right = int((cell.end-startAt)*1.0/span*width)
    return {x:x,width:right-x}
end function

function EpgTime(at as integer) as string
    date = CreateObject("roDateTime")
    date.fromSeconds(at)
    date.toLocalTime()
    hour = date.getHours()
    suffix = "AM"
    if hour >= 12 then suffix = "PM"
    hour = hour mod 12
    if hour = 0 then hour = 12
    minute = date.getMinutes().toStr()
    if len(minute) = 1 then minute = "0"+minute
    return hour.toStr()+":"+minute+" "+suffix
end function
