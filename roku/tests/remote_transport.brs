sub Main()
    m.top = {cancel:false}
    result = remoteFetch("GET","/api/bootstrap",invalid)
    remoteAssert(result.ok and result.data.contract_version = 3,"v3 bootstrap over verified TLS")
    result = remoteFetch("POST","/api/echo",{card:{identity:{id:"opaque",kind:"movie"}}})
    remoteAssert(result.ok and result.data.method = "POST" and result.data.authenticated and result.data.origin_valid,"POST, bearer and current backend Origin requirement")
    query = {values:[{id:"genre",values:["Sci-Fi & Fantasy","日本語 + café"]}],metadata_origin:{provider_id:"fixture",scope:"A/B?C"},empty:"",enabled:false,offset:17,optional:invalid}
    result = remoteFetch("GET","/api/echo?existing=kept",invalid,query)
    remoteAssert(result.ok and result.data.body = invalid,"structured GET query never becomes a request body")
    remoteAssert(result.data.query.existing[0] = "kept" and result.data.query.empty[0] = "","Task query preserves existing and empty parameters")
    remoteAssert(REqual(ParseJson(result.data.query.values[0]),query.values),"Task encodes nested selections and UTF-8 exactly")
    remoteAssert(REqual(ParseJson(result.data.query.metadata_origin[0]),query.metadata_origin),"Task encodes opaque metadata origin exactly")
    remoteAssert(result.data.query.enabled[0] = "false" and result.data.query.offset[0] = "17" and result.data.query.optional[0] = "null","Task preserves typed scalar query values")
    result = remoteFetch("DELETE","/api/echo",invalid,{card:{identity:{kind:"movie",id:"opaque / +"}}})
    remoteAssert(result.ok and ParseJson(result.data.query.card[0]).identity.id = "opaque / +","DELETE scopes opaque card in query without a body")
    result = remoteFetch("PUT","/api/echo",{value:false})
    remoteAssert(result.ok and result.data.method = "PUT" and result.data.body.value = false,"PUT body")
    result = remoteFetch("DELETE","/api/empty",invalid)
    remoteAssert(result.ok and result.status = 204,"empty DELETE")
    result = remoteFetch("GET","/api/old",invalid)
    remoteAssert(not result.ok,"malformed current response")
    result = remoteFetch("GET","/api/denied",invalid)
    remoteAssert(not result.ok and result.status = 403 and instr(1,result.error,"private-fixture") = 0,"safe denied response")
    result = remoteFetch("GET","/api/profiles/7/live/channel-1/guide",invalid)
    remoteAssert(result.ok and result.data.view.now_millis = 1800000000000#, "current guide timestamps survive production HTTPS parsing")
    result = remoteFetch("GET","/api/profiles/7/live/bad-window/guide",invalid)
    remoteAssert(not result.ok and result.contract_error = true, "malformed guide is rejected in the Task boundary")
    result = remoteFetch("GET","/api/large",invalid)
    remoteAssert(not result.ok,"bounded response")
    result = remoteFetch("GET","https://other.test/api/echo",invalid)
    remoteAssert(not result.ok,"API escape refused")
    m.top.cancel = true
    result = remoteFetch("GET","/api/echo",invalid)
    remoteAssert(not result.ok and result.error = "Cancelled","cooperative cancellation")
    current = {base:"https://example.test",auth_origin:"https://example.test",auth_version:3,access_token:"current-access",refresh_token:"current-refresh",last_profile_id:"stable-profile",account_id:"stable-account"}
    stored = rStored(current,invalid)
    remoteAssert(stored.access_token = "current-access" and stored.account_id = "stable-account","current credentials and account ownership preserved")
    remoteAssert(not stored.doesExist("last_profile_id"),"profile selection is not restored from client registry metadata")
    remoteAssert(rStored(current,{base:"https://new.test"}).refresh_token = "","origin boundary clears grant")
    current.auth_version = 2
    remoteAssert(rStored(current,invalid).refresh_token = "","unsupported storage version rejected")
    remoteAssert(rStored({server:"https://example.test",token:"obsolete"},invalid).base = "","split registry fields are not imported")
    remoteAssert(ROrigin("https://example.test/path") = "" and ROrigin("http://example.test") = "","origin validation")
    print "REMOTE_TRANSPORT_OK"
end sub
function remoteFetch(method as string,path as string,body as dynamic, query = invalid as dynamic) as object
    q = {base:"FIXTURE_ORIGIN",path:path,method:method,body:body,query:query,access_token:"fixture-access",request_id:"1-1"}
    return rHttp(q,{ok:false,status:0,error:"",data:invalid})
end function
sub remoteAssert(ok as boolean,message as string)
    if not ok
        print "REMOTE_TRANSPORT_FAILED: ";message
        stop
    end if
end sub
