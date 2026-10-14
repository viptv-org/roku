sub Main()
    m.mode = "collection" : m.collection = "favorites" : m.profile = "7"
    m.list = {itemFocused:32} : m.collectionItems = items(0) : m.collectionNextOffset = 40
    m.collectionAppending = true : m.collectionLoading = false : m.calls = 0 : m.published = 0
    collectionMaybeLoad()
    check(m.calls = 1 and instr(1,m.sent.path,"offset=40") > 0,"approaching the visible end requests the next page")
    collectionMaybeLoad()
    check(m.calls = 1,"held input cannot schedule duplicate page requests")
    collectionPage({ok:true,data:{items:items(40),offset:40,next_offset:80}},"My List","Help","librarypage")
    check(m.items.count() = 80 and m.list.jumpToItem = 32,"append keeps every loaded item and the focused index")
    for each item in m.items
        check(item.action = invalid,"collection has no manual next or previous controls")
    end for
    m.mode = "detail" : m.list.itemFocused = 79
    collectionMaybeLoad()
    check(m.calls = 1,"leaving the collection retires demand")
    m.mode = "collection" : m.collectionAppending = false : m.collectionRestoreIndex = 67 : m.published = 0
    collectionPage({ok:true,data:{items:items(0),offset:0,next_offset:40}},"My List","Help","librarypage")
    check(m.published = 0 and m.calls = 2,"refresh loads enough data before restoring a distant focus position")
    collectionPage({ok:true,data:{items:items(40),offset:40,next_offset:invalid}},"My List","Help","librarypage")
    check(m.published = 1 and m.list.jumpToItem = 67,"refresh restores the original index without intermediate focus jumps")
    before = m.items.count()
    m.status = {text:""}
    collectionPage({ok:false},"My List","Help","librarypage")
    check(m.items.count() = before,"transient append failure keeps usable loaded content")
    print "ROKU_COLLECTION_PAGING_OK"
end sub

function items(offset as integer) as object
    output = []
    for i = offset to offset+39
        output.push({id:i.toStr(),type:"movie",name:"Title"})
    end for
    return output
end function

sub request(method as string,path as string,body as dynamic,tag as string)
    m.calls++
    m.sent = {path:path}
end sub

sub rows(title as string,values as object,mode as string,help as string,enter = true as boolean)
    m.items = values
    m.published++
end sub

function continuationPath(resource as string) as string
    return "/api/profiles/7/continue/" + resource
end function

sub check(value as boolean,label as string)
    if not value then throw label
end sub
