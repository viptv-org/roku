sub Main()
    m.accountEpoch = 8
    m.config = {base:"https://fixture.invalid"}
    m.pairQr = {uri:"",visible:false,loadStatus:"loading"}
    m.pairQrTimer = {control:""}
    m.authTimer = {control:""}
    m.authLoading = {visible:false}
    m.authLoadingSpinner = {control:""}
    m.nodes = {pairPanel:{visible:false},pairInstruction:{text:""},pairAddress:{text:""},pairCode:{text:""},pairQrSurface:{visible:false}}
    GetGlobalAA().fixtureNodes = m.nodes
    m.top = {findNode:FindFixtureNode}
    m.pairing = {expires_at:accountNow()+120}
    data = {qr_uri:"/api/device/qr/fixture",verification_uri:"https://fixture.invalid/device",user_code:"FIXTURE"}
    accountShowQr(data)
    check(m.authLoading.visible and not m.nodes.pairPanel.visible and m.pairQrTimer.control = "start","pairing stays covered while QR loads")
    check(m.pairQr.uri = "https://fixture.invalid/api/device/qr/fixture","QR preloads from the configured origin")
    m.pairQr.loadStatus = "ready"
    accountQrLoaded()
    check(not m.authLoading.visible and m.nodes.pairPanel.visible and m.pairQr.visible,"ready QR reveals completed pairing")
    check(m.nodes.pairCode.text = "FIXTURE" and m.pairQrTimer.control = "stop","code and image reveal together")
    m.pairQr.loadStatus = "loading"
    accountShowQr(data)
    accountQrTimeout()
    check(not m.authLoading.visible and not m.pairQr.visible and not m.nodes.pairQrSurface.visible,"timeout reveals manual pairing without empty QR frame")
    check(m.nodes.pairAddress.text = "Visit https://fixture.invalid/device","manual fallback remains usable")
    accountShowQr(data)
    m.pairQr.loadStatus = "failed"
    accountQrLoaded()
    check(not m.authLoading.visible and m.nodes.pairCode.text = "FIXTURE","failed image retains manual code")
    m.pairQr.loadStatus = "loading"
    accountShowQr(data)
    m.accountEpoch++
    m.pairQr.loadStatus = "ready"
    accountQrLoaded()
    check(m.authLoading.visible and not m.nodes.pairPanel.visible,"old account callback cannot reveal a stale code")
    accountHideQr()
    accountQrTimeout()
    check(m.pairVisual = invalid and not m.nodes.pairPanel.visible,"cancelled preload cannot reveal after timeout")
    m.pairing.expires_at = accountNow()-1
    m.pairQr.loadStatus = "loading"
    accountShowQr(data)
    m.pairQr.loadStatus = "ready"
    accountQrLoaded()
    check(m.retryShown and not m.nodes.pairPanel.visible,"expired code goes to retry instead of becoming visible")
    print "PAIRING_PRELOAD_OK"
end sub
function FindFixtureNode(id as string) as object
    return GetGlobalAA().fixtureNodes[id]
end function
sub rows(title as string, items as object, mode as string, subtitle as string)
    m.mode = mode
    m.retryShown = items.count() > 0
    if m.retryShown then accountEndLoading()
end sub
sub check(ok as boolean, label as string)
    if not ok
        print "FAIL: "; label
        stop
    end if
end sub
