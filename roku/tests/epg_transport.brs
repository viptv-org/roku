' Controller routing and bounded guide work; auth propagation has its own runtime contract.
sub Main()
    m.mode = "epg"
    m.profile = "7"
    m.queue = []
    m.sent = []
    m.epgSerial = 0
    m.epgPending = {}
    m.epgGrid = {visible:true,needed:["a","b","c","d","e"],route:{filter:{id:"all"},offset:0,focusEnd:false}}
    epgPump()
    verify(m.sent.count()=3 and m.epgPending.count()=3,"guide requests bounded to three")
    epgPump()
    verify(m.sent.count()=3,"pending requests are not duplicated")
    epgResponse("epg:guide:a",{ok:false})
    verify(m.epgPending.count()=2 and m.epgGrid.guide.ok=false,"failure releases capacity and reaches cache")
    m.epgGrid.needed = ["b","c","d","e"]
    epgPump()
    verify(m.sent.count()=4 and m.sent[3].path="/api/guide/d","next visible guide fills released slot")
    m.queue = [{tag:"epg:channels:0"},{tag:"unrelated"}]
    epgRouteChanged()
    verify(m.queue.count()=1 and m.queue[0].tag="unrelated","superseded queued pages coalesced")
    epgResponse("epg:channels:0",{ok:true,data:{channels:[{id:"stale"}],total:1}})
    verify(m.epgGrid.data=invalid,"late channel response ignored")
    epgResponse("epg:channels:1",{ok:true,data:{channels:[{id:"current"}],total:1}})
    verify(m.epgGrid.data.channels[0].id="current","current page accepted")
    m.mode = "home"
    epgResponse("epg:channels:1",{ok:true,data:{channels:[],total:0}})
    verify(m.epgGrid.data.channels.count()=1,"closed guide ignores response")
    print "EPG_TRANSPORT_OK"
end sub
sub request(method,path,body,tag)
    m.sent.push({path:path,tag:tag})
end sub
sub verify(ok as boolean,message as string)
    if not ok then throw message
end sub
