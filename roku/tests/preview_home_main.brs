' TEST-ONLY entry point. Copy over source/main.brs in a disposable preview project.
' Never included in the production development ZIP; only loopback fictional fixtures.
sub Main()
    registry = CreateObject("roRegistrySection", "VIPTV")
    registry.Write("config", FormatJson({base:"http://127.0.0.1:18770",access_token:"viptv-ui-fixture-only",refresh_token:"fixture-refresh",last_profile_id:"1",account_id:"fixture-account",auth_version:3,auth_origin:"http://127.0.0.1:18770"}))
    registry.Flush()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("MainScene")
    screen.Show()
    while true
        message = wait(0, port)
        if type(message) = "roSGScreenEvent" and message.IsScreenClosed() then return
    end while
end sub
