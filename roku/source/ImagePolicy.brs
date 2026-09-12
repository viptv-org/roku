' Resize only public artwork. Provider/addon credentials never leave their origin.
function ImagePixels(size as integer) as integer
    if m.imageScale = invalid
        m.imageScale = 1.0
        display = CreateObject("roDeviceInfo").getDisplaySize()
        if display <> invalid
            if display.w >= 1920 then m.imageScale = 1.5
        end if
    end if
    return int(size*m.imageScale)
end function

function ImageUrl(uri as string, width as integer, height as integer, large = false as boolean, logo = false as boolean) as string
    original = uri
    ' Existing episode thumbnails may already use wsrv. Re-size the original once.
    if left(uri,17) = "https://wsrv.nl/?"
        for each pair in mid(uri,18).split("&")
            if left(pair,4) = "url="
                ' Card renderers cannot construct MAIN/TASK-only roUrlTransfer.
                encoded = mid(pair,5)
                escapes = CreateObject("roRegex","%[0-9A-Fa-f]{2}","")
                if instr(1,escapes.replaceAll(encoded,""),"%") > 0 then return original
                try
                    uri = encoded.Unescape()
                catch error
                    return original
                end try
            end if
        end for
    end if
    safe = CreateObject("roRegex","^https://(image\.tmdb\.org|artworks\.thetvdb\.com|episodes\.metahub\.space|images\.metahub\.space|live\.metahub\.space|assets\.fanart\.tv|i\.imgur\.com)/[^?#@]+$","")
    if not safe.isMatch(uri) then return original
    w = ImagePixels(width)
    h = ImagePixels(height)
    ' Do not ask TMDB for an original-sized file only to reduce it at the TV.
    tmdb = CreateObject("roRegex","^https://image\.tmdb\.org/t/p/(w[0-9]+|original)/","")
    if tmdb.isMatch(uri)
        bucket = "w500"
        if w > 500 then bucket = "w1280"
        if w > 1280 then bucket = "original"
        uri = tmdb.replace(uri,"https://image.tmdb.org/t/p/"+bucket+"/")
    end if
    quality = "85"
    if large then quality = "95"
    format = "jpg"
    fit = "cover"
    if logo
        format = "png"
        fit = "inside"
    end if
    return "https://wsrv.nl/?url="+Enc(uri)+"&w="+w.toStr()+"&h="+h.toStr()+"&fit="+fit+"&output="+format+"&q="+quality+"&we"
end function
