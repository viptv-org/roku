sub Main()
    m.top = {cancel:false}
    result = remoteFetch("GET","/api/bootstrap",invalid)
    remoteAssert(result.ok and result.data.contract_version = 3,"v3 bootstrap over verified TLS")
    result = remoteFetch("POST","/api/echo",{card:{identity:{id:"opaque",kind:"movie"}}})
    remoteAssert(result.ok and result.data.method = "POST" and result.data.authenticated,"POST and bearer")
    result = remoteFetch("PUT","/api/echo",{value:false})
    remoteAssert(result.ok and result.data.method = "PUT" and result.data.body.value = false,"PUT body")
    result = remoteFetch("DELETE","/api/empty",invalid)
    remoteAssert(result.ok and result.status = 204,"empty DELETE")
    result = remoteFetch("GET","/api/old",invalid)
    remoteAssert(not result.ok,"malformed current response")
    result = remoteFetch("GET","/api/denied",invalid)
    remoteAssert(not result.ok and result.status = 403 and instr(1,result.error,"private-fixture") = 0,"safe denied response")
    result = remoteFetch("GET","/api/large",invalid)
    remoteAssert(not result.ok,"bounded response")
    result = remoteFetch("GET","https://other.test/api/echo",invalid)
    remoteAssert(not result.ok,"API escape refused")
    m.top.cancel = true
    result = remoteFetch("GET","/api/echo",invalid)
    remoteAssert(not result.ok and result.error = "Cancelled","cooperative cancellation")
    old = {base:"https://example.test",auth_origin:"https://example.test",auth_version:2,token:"old-access",refresh_token:"old-refresh",profile:"stable-profile",account_id:"stable-account"}
    migrated = rStored(old,invalid)
    remoteAssert(migrated.access_token = "old-access" and migrated.last_profile_id = "stable-profile","existing credentials and profile preserved")
    remoteAssert(rStored(old,{base:"https://new.test"}).refresh_token = "","origin boundary clears grant")
    remoteAssert(ROrigin("https://example.test/path") = "" and ROrigin("http://example.test") = "","origin validation")
    print "REMOTE_TRANSPORT_OK"
end sub
function remoteFetch(method as string,path as string,body as dynamic) as object
    q = {base:"FIXTURE_ORIGIN",path:path,method:method,body:body,access_token:"fixture-access",request_id:"1-1"}
    return rHttp(q,{ok:false,status:0,error:"",data:invalid})
end function
sub remoteAssert(ok as boolean,message as string)
    if not ok
        print "REMOTE_TRANSPORT_FAILED: ";message
        stop
    end if
end sub
