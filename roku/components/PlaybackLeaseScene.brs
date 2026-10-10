' Render-thread lifetime only. No media URL is followed for backend control.
sub registerRokuPlaybackLease(data as object, connection as object)
    if Txt(data.delivery_kind) <> "gateway" then return
    clock = CreateObject("roTimespan") : clock.mark()
    renew = CreateObject("roTimespan") : renew.mark()
    remaining = data.expires_at - CreateObject("roDateTime").asSeconds()
    if remaining > 60 then remaining = 60
    previous = m.playbackLeases[Txt(data.id)]
    acknowledged = previous <> invalid and previous.frame_reported = true
    m.playbackLeases[Txt(data.id)] = {frame_reported:acknowledged,connection:connection,url:data.url,clock:clock,remaining_seconds:remaining,renew:renew,renew_after_seconds:data.renew_after_seconds,pending:false}
    m.leaseTick.control = "start"
end sub

sub reportRokuPlaybackFirstFrame()
    if m.playbackLeases = invalid then return
    if not m.playbackLeases.DoesExist(Txt(m.session)) then return
    lease = m.playbackLeases[Txt(m.session)]
    if lease.frame_reported = true then return
    lease.frame_reported = true
    request("POST",PlaybackSessionPath(lease.connection,Txt(m.session)) + "/first-frame",{},"sidefirstframe",lease.connection)
end sub

sub rokuPlaybackFirstFrameResponse(result as object, origin as object)
    identity = Mid(Txt(origin.path),18).split("/")[0]
    if identity <> Txt(m.session) then return
    if not m.playbackLeases.DoesExist(identity) then return
    lease = m.playbackLeases[identity]
    if Txt(origin.access_token) <> Txt(lease.connection.access_token) then return
    if not result.ok then retireRokuPlaybackLeases(Txt(result.error,"Playback startup acknowledgement was refused. Start playback again."))
end sub

sub rokuPlaybackLeaseTick()
    if m.playbackLeases.count() = 0
        m.leaseTick.control = "stop"
        return
    end if
    for each identity in m.playbackLeases
        lease = m.playbackLeases[identity]
        if lease.clock.TotalMilliseconds() >= lease.remaining_seconds * 1000
            retireRokuPlaybackLeases("Playback authorization expired. Start playback again.")
            return
        end if
        if not lease.pending and lease.renew.TotalMilliseconds() >= lease.renew_after_seconds * 1000
            lease.pending = true
            lease.renew.mark()
            request("POST",PlaybackSessionPath(lease.connection,identity) + "/heartbeat",{},"sideheartbeat",lease.connection)
        end if
    end for
end sub

sub rokuPlaybackHeartbeatResponse(result as object, origin as object)
    identity = Mid(Txt(origin.path),18).split("/")[0]
    if not m.playbackLeases.DoesExist(identity) then return
    lease = m.playbackLeases[identity]
    if Txt(origin.access_token) <> Txt(lease.connection.access_token) then return
    lease.pending = false
    if lease.clock.TotalMilliseconds() >= lease.remaining_seconds * 1000
        retireRokuPlaybackLeases("Playback authorization expired. Start playback again.")
        return
    end if
    if not result.ok
        ' Network outages cannot extend expiry. A definite refusal retires media.
        if result.status = 0 or result.status = 408 or result.status = 429 or (result.status >= 500 and result.status < 600)
            lease.renew_after_seconds = 2
            lease.renew.mark()
            return
        end if
        retireRokuPlaybackLeases(Txt(result.error,"Playback authorization was refused. Start playback again."))
        return
    end if
    if Txt(result.data.id) <> identity or Txt(result.data.url) <> lease.url or Txt(result.data.delivery_kind) <> "gateway"
        retireRokuPlaybackLeases("The server returned a different playback session. Start playback again.")
        return
    end if
    registerRokuPlaybackLease(result.data,lease.connection)
end sub

sub retireRokuPlaybackLeases(reason as string)
    leases = m.playbackLeases
    m.playbackLeases = {}
    m.leaseTick.control = "stop"
    cancelBrowse()
    stopPlayback(false)
    for each identity in leases
        request("DELETE",PlaybackSessionPath(leases[identity].connection,identity),invalid,"cleanup",leases[identity].connection)
    end for
    sourceExhausted(reason)
end sub
