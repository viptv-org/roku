sub Main()
    m.top = {cancel:false}
    m.calls = []
    m.behavior = "normal"
    original = {data:{item:parentCard(),episodes:episodes(0,24),recommendations:[],next_cursor:"24"}}
    result = EngineDetailPages({path:"/api/v3/meta/series/opaque-parent",base:"https://fixture.example"},original)
    check(result.meta.videos.count() = 1242, "large series automatically collects every bounded episode page")
    check(result.meta.videos[1241].id = "opaque/1241" and result.meta.videos[1241].episode = 42, "opaque episode identities and coordinates survive paging")
    check(m.calls.count() = 10 and instr(1,m.calls[0],"offset=24&limit=128") > 0, "canonical host cursor drives bounded requests")
    m.behavior = "repeated"
    check(EngineDetailPages({path:"/api/v3/meta/series/opaque-parent"},original) = invalid, "repeated cursor cannot loop forever")
    m.behavior = "replaced"
    check(EngineDetailPages({path:"/api/v3/meta/series/opaque-parent"},original) = invalid, "a different parent response cannot contaminate the episode list")
    m.top.cancel = true
    before = m.calls.count()
    check(EngineDetailPages({path:"/api/v3/meta/series/opaque-parent"},original) = invalid and m.calls.count() = before, "cancelled screen does not schedule another page")
    print "ROKU_ENGINE_PAGES_OK"
end sub

function parentCard() as object
    return {identity:{id:"opaque-parent",kind:"series",ids:[],episode:invalid,edition:invalid},title:"Series",provider_id:"fixture"}
end function

function episodes(offset as integer, limit as integer) as object
    values = []
    last = offset + limit - 1
    if last > 1241 then last = 1241
    for i = offset to last
        values.push({identity:{id:"opaque/"+i.toStr(),kind:"series",ids:[],episode:{order:"aired",season:int(i/100)+1,episode:(i mod 100)+1},edition:invalid},parent_identity:parentCard().identity,title:"Episode",provider_id:"fixture"})
    end for
    return values
end function

function HttpRequestRaw(request as object, result as object, method as string, sanitize as boolean) as object
    m.calls.push(request.path)
    offset = val(EngineUrlParameter(request.path,"offset"))
    nextCursor = invalid
    if offset + 128 < 1242 then nextCursor = (offset+128).toStr()
    if m.behavior = "repeated" then nextCursor = offset.toStr()
    parent = parentCard()
    if m.behavior = "replaced" then parent.identity.id = "another-parent"
    return {ok:true,data:{item:parent,episodes:episodes(offset,128),next_cursor:nextCursor}}
end function

sub check(value as boolean, label as string)
    if not value
        print "FAILED: " + label
        stop
    end if
end sub
