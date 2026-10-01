' Account connection copy is separate from Home's progressive artwork loading.
sub initStartup()
    m.startupText = m.top.findNode("startupText")
    m.homeInitialLoading = false
end sub

sub startupStatus(text as string)
    if m.startupText <> invalid then m.startupText.text = text
end sub

sub startupHomeBegin()
    startupCancel()
    accountEndLoading()
end sub

sub startupCancel()
    m.homeInitialLoading = false
end sub

' Ignore replies belonging to an obsolete preloading transaction.
sub startupArtworkResponse(tag as string, result as object)
end sub
