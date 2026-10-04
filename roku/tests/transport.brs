' Run tests/mock_api.py on loopback:18764 before this simulator-only test.
sub Main()
    m.top = {cancel:false}
    result = fetch("GET","/api/profiles",invalid)
    check(result.ok and result.data.count() = 1,"GET and shape filtering")
    check(result.data[0].id = "1","numeric profile ID normalized")
    result = fetch("POST","/api/profiles",{name:"New viewer"})
    if not result.ok then print "POST diagnostic "; FormatJson(result)
    check(result.ok and result.data.name = "New viewer","POST JSON body")
    result = fetch("PUT","/api/profiles/1/favorites",{id:"tt1",type:"movie",name:"Movie"})
    check(result.ok,"PUT verb preserved")
    result = fetch("DELETE","/api/profiles/1/favorites/movie/tt1",invalid)
    check(result.ok and result.status = 204,"DELETE and empty response")
    result = fetch("GET","/api/profiles?bad=1",invalid)
    check(not result.ok and result.error = "Unexpected API response","null envelope rejected")
    result = fetch("GET","/api/profiles?forbidden=1",invalid)
    check(not result.ok and result.status = 403 and result.error = "VIPTV refused this request. Check your profile permissions.","HTTP error hides credentials")
    result = fetch("GET","/api/profiles?large=1",invalid)
    check(not result.ok and result.error = "Response exceeds 2 MiB","oversized response rejected")
    result = fetch("GET","https://evil.example/api/profiles",invalid)
    check(not result.ok,"off-origin request blocked before network")
    query = Enc("shared query")
    movie = fetch("GET","/api/discover?type=movie&skip=0&search=" + query,invalid)
    series = fetch("GET","/api/discover?type=series&skip=0&search=" + query,invalid)
    check(movie.ok and series.ok,"one query reaches movie and series HTTP scopes")
    check(movie.data.metas[0].type = "movie" and series.data.metas[0].type = "series","combined transport preserves typed discovery envelopes")
    check(movie.data.metas.count() + series.data.metas.count() = 2,"combined query returns distinct scope results")
    m.top.cancel = true
    m.top.request = {method:"GET",tag:"cancelled",path:"/api/profiles",base:"http://127.0.0.1:18764",access_token:"fixture-token"}
    RunRequest()
    check(not m.top.result.ok and m.top.result.error = "Cancelled","cooperative cancellation")
    print "ROKU_TRANSPORT_OK"
end sub

function fetch(method as string,path as string,body as dynamic) as object
    request = {method:method,path:path,body:body,base:"http://127.0.0.1:18764",access_token:"fixture-token",tag:"test"}
    return HttpRequest(request,{tag:"test",ok:false,data:invalid,error:"",status:0},method)
end function

sub check(condition as boolean,label as string)
    if not condition
        print "TEST_FAIL "; label
        stop
    end if
end sub
