' Task-only platform effects. No legacy provider/presentation policies shipped.
sub init()
    m.top.functionName = "runRemoteRequest"
end sub
sub runRemoteRequest()
    q = m.top.request
    result = {tag:q.tag,ok:false,status:0,data:invalid,error:""}
    if q.method = "CONFIG_LOAD" or q.method = "CONFIG_SAVE"
        result = rStore(q,result)
    else
        result = rHttp(q,result)
    end if
    m.top.result = result
end sub

function rHttp(q as object, result as object) as object
    origin = ROrigin(q.base)
    route = RText(q.path)
    if origin = "" or left(route,5) <> "/api/" or instr(1,route,chr(92)) > 0 or instr(1,route,chr(10)) > 0 or instr(1,route,chr(13)) > 0
        result.error = "A secure server connection is required."
        return result
    end if
    if q.method <> "GET" and q.method <> "POST" and q.method <> "PUT" and q.method <> "PATCH" and q.method <> "DELETE"
        result.error = "Unsupported request."
        return result
    end if
    token = RText(q.access_token)
    if instr(1,token,chr(10)) > 0 or instr(1,token,chr(13)) > 0
        result.error = "Invalid account credential."
        return result
    end if
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.initClientCertificates()
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.retainBodyOnError(true)
    transfer.setUrl(origin+route)
    transfer.addHeader("Accept","application/json")
    transfer.addHeader("Content-Type","application/json")
    transfer.addHeader("x-viptv-image-delivery","direct")
    transfer.addHeader("User-Agent","VIPTV-Roku/2")
    if token <> "" then transfer.addHeader("Authorization","Bearer "+token)
    transfer.setRequest(q.method)
    responsePath = "tmp:/remote-"+q.request_id+"-"+transfer.getIdentity().toStr()+".json"
    fs = CreateObject("roFileSystem")
    maxBytes = 2097152
    clock = CreateObject("roTimespan")
    timeout = 60000
    if q.method = "GET"
        started = transfer.asyncGetToFile(responsePath)
    else
        payload = ""
        if q.body <> invalid then payload = FormatJson(q.body)
        if len(payload) > maxBytes
            result.error = "The request is too large."
            return result
        end if
        started = transfer.asyncPostFromString(payload)
    end if
    if not started
        result.error = "Could not start the request. Try again."
    else
        while true
            if m.top.cancel and q.cleanup <> true
                result.error = "Cancelled"
                exit while
            end if
            if clock.totalMilliseconds() >= timeout
                result.error = "The server took too long. Try again."
                exit while
            end if
            file = fs.stat(responsePath)
            if file <> invalid
                if RGet(file,"size",0) > maxBytes
                    result.error = "The server response is too large."
                    exit while
                end if
            end if
            event = wait(100,port)
            if type(event) = "roUrlEvent"
                if event.getSourceIdentity() = transfer.getIdentity()
                    result.status = event.getResponseCode()
                    if q.method = "GET"
                        text = ""
                        file = fs.stat(responsePath)
                        if RGet(file,"size",-1) >= 0 then text = ReadAsciiFile(responsePath)
                    else
                        text = event.getString()
                    end if
                    bytes = CreateObject("roByteArray")
                    bytes.fromAsciiString(text)
                    if bytes.count() > maxBytes
                        result.error = "The server response is too large."
                    else if result.status >= 200 and result.status < 300
                        if result.status = 204 and q.method = "DELETE"
                            result.ok = true
                            result.data = {ok:true}
                        else
                            value = ParseJson(text)
                            if RObject(value) or GetInterface(value,"ifArray") <> invalid
                                result.ok = true
                                result.data = value
                                result = RemoteWireResponse(q,result)
                            else
                                result.error = "The server returned an invalid response."
                            end if
                        end if
                    else
                        result.error = rHttpError(result.status)
                        if (result.status = 400 or result.status = 401 or result.status = 403) and len(text) < 4096 and left(text.trim(),1) = "{"
                            error = ParseJson(text)
                            result.auth_code = RText(RGet(error,"error_code"),RText(RGet(error,"error")))
                        end if
                    end if
                    exit while
                end if
            end if
        end while
    end if
    transfer.asyncCancel()
    fs.delete(responsePath)
    return result
end function

function rHttpError(status as integer) as string
    if status = 401 then return "Your session expired. Sign in again."
    if status = 403 then return "This action needs permission or the parent PIN."
    if status = 404 then return "This server needs an update to support this action."
    if status = 409 then return "This information changed. Refresh and try again."
    if status = 429 then return "Too many requests. Try again shortly."
    if status = 400 or status = 422 then return "Check the entered values and try again."
    return "Could not reach the server. Try again."
end function
