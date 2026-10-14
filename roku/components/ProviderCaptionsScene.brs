sub beginProviderSubtitles()
    if m.externalSubtitlesSupported <> true or m.playbackLive = true or m.playItem = invalid then return
    if m.providerSubtitleSequence = invalid then m.providerSubtitleSequence = 0
    m.providerSubtitleSequence++
    m.providerSubtitleTag = "provider-subtitles:"+m.providerSubtitleSequence.toStr()
    m.providerSubtitleOwner = {session:m.session,owner:TrackOwner(m.playItem),profile:m.profile}
    m.trackChoices = [{action:"back",name:"Back to player"}]
    m.choiceKind = "playerTracks"
    m.choicePanel.model = {title:"Add-on subtitles",description:"Finding subtitles…",items:m.trackChoices,index:0}
    m.choicePanel.visible = true
    path = "/api/v3/subtitles/"+Enc(Txt(m.playItem.type))+"/"+Enc(Txt(m.playItem.id))
    request("GET",path,invalid,m.providerSubtitleTag)
end sub

sub providerSubtitleResponse(tag as string, result as object)
    owner = m.providerSubtitleOwner
    if owner = invalid or tag <> m.providerSubtitleTag or m.choicePanel.visible <> true then return
    if owner.session <> m.session or owner.owner <> TrackOwner(m.playItem) or owner.profile <> m.profile then return
    if m.choiceKind <> "playerTracks" or m.trackKind <> "subtitles" then return
    m.trackChoices = []
    message = "No add-on subtitles are available for this title."
    if result.ok
        for each candidate in Bounded(result.data.candidates,200)
            if GetInterface(candidate,"ifAssociativeArray") <> invalid
                id = StablePreferenceText(candidate.id,128)
                if id <> ""
                    name = Txt(candidate.label,Txt(candidate.language,"Subtitle"))
                    if Txt(m.providerCaptionId) = id then name += " · Current"
                    m.trackChoices.push({action:"provider",subtitle_id:id,language:Txt(candidate.language),name:name})
                end if
            end if
        end for
        if m.trackChoices.count() > 0 then message = "Choose a subtitle track."
    else
        message = "Add-on subtitles are unavailable. Try again."
    end if
    m.trackChoices.push({action:"back",name:"Back to player"})
    m.choicePanel.model = {title:"Add-on subtitles",description:message,items:m.trackChoices,index:0}
end sub
