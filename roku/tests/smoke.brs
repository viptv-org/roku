' Run with source/Util.brs and this file (not source/main.brs).
sub Main()
    m.failures = 0
    Check(Txt(invalid, "Unknown") = "Unknown", "missing title fallback")
    Check(Txt({ name: "Movie" }, "Unknown") = "Unknown", "object is not text")
    Check(Txt(42) = "42", "numeric provider ID")
    Check(Txt(false) = "false", "boolean text")
    Check(Enc("tt123:2:7 /?&+") = "tt123%3A2%3A7%20%2F%3F%26%2B", "episode query encoding")
    Check(Enc("Amélie 東京") = "Am%C3%A9lie%20%E6%9D%B1%E4%BA%AC", "UTF8 search encoding")
    Check(Enc("AZaz09-._~") = "AZaz09-._~", "unreserved characters")
    Check(ResolveUrl("https://tv.example:8080/mount/", "api/live") = "https://tv.example:8080/mount/api/live", "mount relative URL")
    Check(ResolveUrl("https://tv.example/mount", "/api/playback/abc/index.m3u8?cap=x") = "https://tv.example/api/playback/abc/index.m3u8?cap=x", "root playback URL")
    Check(ResolveUrl("http://tv.example", "https://cdn.example/movie.mp4") = "https://cdn.example/movie.mp4", "absolute HTTPS URL")
    Check(ResolveUrl("http://tv.example", "file:///tmp/a") = "", "reject local scheme")
    Check(ResolveUrl("http://tv.example", "javascript:alert(1)") = "", "reject script scheme")
    Check(ResolveUrl("http://tv.example", "//other.example/a") = "", "reject network path")
    Check(ResolveUrl("http://tv.example", "https://user:secret@other.example/a") = "", "reject embedded credentials")
    Check(ResolveUrl("http://tv.example", "https://") = "", "reject absent host")
    Check(ResolveUrl("not-a-server", "/api/live") = "", "reject invalid base")
    channels = [{ id: "1", type: "live" }, { id: "2", type: "live" }, { id: "3", type: "live" }]
    subset = Bounded(channels, 2)
    Check(subset.Count() = 2 and channels.Count() = 3, "bound without mutating source")
    Check(Bounded(channels, 0).Count() = 0, "zero bound")
    Check(Bounded(channels, -1).Count() = 0, "negative bound")
    Check(Bounded(invalid, 100).Count() = 0, "missing list")
    Check(Bounded({ channels: channels }, 100).Count() = 0, "wrong list type")
    live = PlaybackBody(channels[0], "p1", invalid, -20, false)
    Check(live.stream_id = "" and not live.DoesExist("channel_id"), "unresolved live channel never substitutes its channel ID")
    resolved = PlaybackBody({ type: "live", id: "1", stream_id: "opaque-live-source" }, "p1", invalid, 0, false)
    Check(resolved.stream_id = "opaque-live-source" and not resolved.DoesExist("channel_id"), "live uses the resolved opaque source ID")
    Check(not live.DoesExist("profile_id") and live.position = 0, "selected profile comes only from authenticated session and resume is nonnegative")
    Check(live.capabilities.max_height = 720 and live.capabilities.h264 and live.capabilities.aac and not live.capabilities.hevc, "safe unknown-device codecs")
    caps = { max_width: 1920, max_height: 1080, hevc: true }
    vod = PlaybackBody({ type: "series", id: "tt123:2:7", stream_id: "opaque-17" }, { id: "p2" }, caps, 123.5, true)
    Check(vod.stream_id = "opaque-17" and not vod.DoesExist("channel_id"), "opaque episode stream ID")
    Check(vod.position = 123.5 and vod.force_transcode and not vod.DoesExist("profile_id"), "resume request cannot override authenticated profile")
    Check(vod.capabilities.max_width = 1920 and vod.capabilities.hevc and caps.Count() = 3, "1080p reports actual HEVC decoder facts without mutation")
    Check(not PlaybackBody({ type: "movie", id: "m" }, invalid, { max_width: 1920, max_height: 1080 }, 0, false).capabilities.hevc, "undeclared HEVC stays off")
    fallback = PlaybackBody({ type: "movie", id: "opaque-18" }, invalid, { max_width: 7680, max_height: 4320, hevc: "yes" }, "bad", false)
    Check(fallback.stream_id = "opaque-18" and not fallback.DoesExist("profile_id"), "stream ID fallback and absent profile")
    Check(fallback.capabilities.max_height = 720 and not fallback.capabilities.hevc and fallback.position = 0, "unsafe capabilities and position rejected")
    uhd = PlaybackBody({ type: "movie", id: "opaque-19" }, invalid, { max_width: 3840, max_height: 2160 }, 0, false)
    Check(uhd.capabilities.max_width = 3840 and uhd.capabilities.max_height = 2160, "declared 2160p decoder envelope is reported")
    if m.failures = 0
        print "ROKU_TEST_OK"
    else
        print "ROKU_TEST_FAILED "; m.failures
    end if
end sub

sub Check(condition as boolean, label as string)
    if not condition
        m.failures++
        print "TEST_FAIL "; label
    end if
end sub
