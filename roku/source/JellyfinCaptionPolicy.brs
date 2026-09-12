' SPDX-License-Identifier: GPL-2.0
' Derived from Jellyfin Roku contributors' VideoPlayerView.bs onSubtitleChange
' and manager/ViewCreator.bs caption selection, revision
' 37ecffd9a589cadaf97771be1b0423e36309182f. See data/JELLYFIN-NOTICE.txt.
' Modified for VIPTV: dependency-free policy; no queue manager or Jellyfin API;
' server session restarts remain MainScene-owned, indices never become native IDs.
function CaptionRestartRequired(captionSelected as boolean, globalMode as string, previousEncoded as boolean) as boolean
    switchWithoutRefresh = true
    if captionSelected
        if LCase(globalMode) <> "on" then switchWithoutRefresh = false
    end if
    if previousEncoded then switchWithoutRefresh = false
    return not switchWithoutRefresh
end function

' Invoke BEFORE assigning new selected-caption content or starting playback.
sub PrepareNativeCaptions(video as object, captionSelected as boolean)
    if captionSelected
        if CaptionRestartRequired(true,video.globalCaptionMode,false) then video.globalCaptionMode = "On"
    else
        video.globalCaptionMode = "Off"
        video.subtitleTrack = ""
    end if
end sub

' Roku may reorder tracks: validate a previously chosen TrackName, never an
' input ffprobe index. VIPTV output contains only the one selected text track.
function MatchNativeCaption(tracks as dynamic, preferredName as string) as string
    if GetInterface(tracks,"ifArray") = invalid then return ""
    firstName = ""
    count = 0
    textName = ""
    textCount = 0
    for each track in tracks
        if GetInterface(track,"ifAssociativeArray") <> invalid
            name = track.TrackName
            if GetInterface(name,"ifString") <> invalid and name <> ""
                if name = preferredName then return name
                if firstName = "" then firstName = name
                count++
                if instr(1,lcase(name),"vtt") > 0
                    textName = name
                    textCount++
                end if
            end if
        end if
    end for
    ' More than one unexpected native track is ambiguous. Do not guess.
    if textCount = 1 then return textName
    if count = 1 then return firstName
    return ""
end function

' Video.captionStyle is per player, so settings do not overwrite system preferences.
' https://developer.roku.com/dev/docs/video#closed-caption-fields
sub ApplyProfileCaptionStyle(video as object, preferences as dynamic)
    style = {}
    if GetInterface(preferences,"ifAssociativeArray") <> invalid
        if preferences.subtitle_size = "small" then style["Text/Size"] = "Small"
        if preferences.subtitle_size = "large" then style["Text/Size"] = "Large"
        if preferences.subtitle_style = "shadow"
            style["Text/Effect"] = "Drop shadow (right)"
            style["Background/Opacity"] = "Off"
        else if preferences.subtitle_style = "opaque"
            style["Text/Color"] = "White"
            style["Background/Color"] = "Black"
            style["Background/Opacity"] = "100%"
        end if
    end if
    video.captionStyle = style
end sub
