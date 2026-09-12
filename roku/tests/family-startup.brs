' Production request/cancellation functions with node-field fakes.
sub Main()
    m.config = {base:"https://fixture.example",access_token:"fixture",last_profile_id:"1"}
    m.queue = []
    m.tasks = []
    m.generation = 1
    m.poll = {control:""}
    m.status = {text:""}
    m.pendingPlayback = true
    request("POST","/api/playback",{channel_id:"family:east"},"playback")
    first = m.queue[0]
    checkFamily(Txt(first.body.startup_id) <> "","live request owns a startup cancellation identifier")
    cancelBrowse()
    checkFamily(not m.pendingPlayback,"leaving channel clears pending playback")
    checkFamily(m.queue.count() = 1 and m.queue[0].method = "DELETE","queued startup removed while explicit cancellation retained")
    checkFamily(m.queue[0].path = "/api/playback/startups/" + first.body.startup_id,"cancellation identifies exact abandoned startup")
    m.queue = []
    m.pendingPlayback = true
    request("POST","/api/playback",{channel_id:"family:west"},"playback")
    second = m.queue[0]
    checkFamily(first.body.startup_id <> second.body.startup_id,"channel changes use fresh startup identifiers")
    m.queue = []
    m.tasks = [{request:second,cancel:false,state:"run"}]
    m.config = {base:"https://new.example",access_token:"new",last_profile_id:"2"}
    cancelBrowse()
    checkFamily(m.tasks[0].cancel,"active live HTTP task is cancelled")
    checkFamily(m.queue[0].base = "https://fixture.example" and m.queue[0].access_token = "fixture","startup cleanup retains original account connection")
    checkFamily(not m.pendingPlayback,"another channel may start without waiting for stale response")
    print "ROKU_FAMILY_STARTUP_OK"
end sub
sub checkFamily(ok as boolean,message as string)
    if not ok then print "FAIL: ";message:stop
end sub
