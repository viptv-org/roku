' A fast series selection may reach playback before Home card metadata arrives.
' Resolve the label without delaying source discovery or changing source intent.
sub playerTitleBegin(item as object)
    m.playerTitleOwner = invalid
    if Txt(item.type) <> "series" or HeroEpisodeTitle(item) <> "" then return
    key = HeroEpisodeKey(item)
    if key = "" then return
    parent = PresentationMetadataId(item)
    path = "/api/meta/series/" + Enc(parent)
    title = ""
    if m.cache[path] <> invalid
        if m.cache[path].data <> invalid then title = HeroEpisodeTitle(item,m.cache[path].data.meta)
    end if
    if title = "" and m.uiHeroMetadata <> invalid
        if m.uiHeroMetadata[path] <> invalid then title = HeroEpisodeTitle(item,m.uiHeroMetadata[path])
    end if
    if title <> ""
        m.playItem.episodeTitle = title
        return
    end if
    if m.playerTitleSequence = invalid then m.playerTitleSequence = 0
    m.playerTitleSequence++
    tag = "playertitle:" + m.playerTitleSequence.toStr()
    m.playerTitleOwner = {tag:tag,id:Txt(item.id),parent:parent,key:key,profile:m.profile,epoch:m.accountEpoch,base:m.config.base}
    request("GET",path,invalid,tag)
end sub

function playerTitleOwnsTag(fullTag as string) as boolean
    owner = m.playerTitleOwner
    if owner = invalid then return false
    return left(fullTag,len(owner.tag)+1) = owner.tag + "|"
end function

sub playerTitleResponse(tag as string, result as object, origin as object)
    owner = m.playerTitleOwner
    if owner = invalid or owner.tag <> tag then return
    m.playerTitleOwner = invalid
    if owner.profile <> m.profile or owner.epoch <> m.accountEpoch or owner.base <> m.config.base then return
    if m.playItem = invalid or Txt(m.playItem.id) <> owner.id then return
    if PresentationMetadataId(m.playItem) <> owner.parent or HeroEpisodeKey(m.playItem) <> owner.key then return
    if origin.account_epoch <> owner.epoch or origin.base <> owner.base then return
    if not result.ok or result.data = invalid or result.data.meta = invalid then return
    meta = result.data.meta
    if Txt(meta.id) <> owner.parent then return
    title = HeroEpisodeTitle(m.playItem,meta)
    if title = "" then return
    m.playItem.episodeTitle = title
    if m.playerReturnDetail <> invalid
        if Txt(m.playerReturnDetail.id) = owner.id then m.playerReturnDetail.episodeTitle = title
    end if
    path = "/api/meta/series/" + Enc(owner.parent)
    if m.cache[path] = invalid
        if m.cacheKeys.count() >= 4 then m.cache.delete(m.cacheKeys.shift())
        m.cacheKeys.push(path)
        m.cache[path] = {time:CreateObject("roDateTime").asSeconds(),data:result.data}
    end if
    if m.uiHeroMetadata = invalid then m.uiHeroMetadata = {}
    contexts = [m.playItem]
    if m.homeData <> invalid
        for each item in Bounded(m.homeData[0],14)
            if PresentationMetadataId(item) = owner.parent then contexts.push(item)
        end for
    end if
    details = HeroMetadataProjection(meta,contexts)
    m.uiHeroMetadata[path] = details
    uiHomeEpisodeMetadata(owner.parent,details)
    if m.mode = "streams" then uiSourceHeader()
    if m.playerOverlay <> invalid and m.playerOverlay.visible then updatePlayer()
end sub
