sub Main()
    good = {id:"good",source:"torrentio",name:"[TB+] Torrentio",title:"Film 1080p H.264 SDR"}
    heavy = {id:"heavy",source:"torrentio",name:"[TB+] Torrentio",title:"Film 2160p HDR x265"}
    unknown = {id:"unknown",source:"pengu",name:"Source",title:"Film"}
    ensure(SourceDisplayLabel(good) = "Torrentio · 1080p · H.264","source display keeps clean identifying title without unverifiable cache badge")
    ensure(SourceDisplayLabel({name:chr(10),title:chr(10)}) = "Source","newline-only rows never render blank")
    release = SourceDisplayLabel({name:"[TB+] Torrentio"+chr(10),title:"Inception.2010.1080p.BluRay.x264.YIFY.mp4"})
    ensure(instr(1,release,"YIFY") > 0 and instr(1,release,chr(10)) = 0,"manual source list retains distinguishing release suffix without raw newlines")
    ensure(SourceScore(good) > SourceScore(unknown) and SourceScore(unknown) > SourceScore(heavy),"soft HD preference, unknown before heavy HDR")
    ensure(SourceScore({name:"UserHEVC",title:"Film"}) = 0,"uploader substring is not a codec token")
    ensure(SourceScore({name:"source",title:"Film HEVC"}) < 0,"bounded codec token is a soft penalty")
    ensure(SourceScore({name:"[TB+] Torrentio",title:"Film"}) = 10,"exact Torrentio cache prefix is a soft bonus")
    for each name in ["[TB+]","Torrentio [TB+]","Uploader [TB+] Torrentio","[TB+] TorrentioUploader","[TB] Torrentio","[tb+] Torrentio","[TB+] Pengu"]
        ensure(SourceScore({name:name,title:"Film"}) = 0,"noncanonical or unrelated cache marker cannot earn bonus")
    end for
    for each hint in ["HDR","HDR10","HDR10+"]
        ensure(SourceScore({name:"Source",title:"Film 1080p " + hint}) = -80,"all bounded HDR variants penalize even 1080p")
    end for
    ensure(SourceScore({name:"UserHDR",title:"Film 1080p HDR1"}) = 20,"HDR uploader substring and HDR1 are not HDR tokens")
    m.sourceRankPatterns.testSentinel = true
    ignored = SourceScore(good)
    ensure(m.sourceRankPatterns.testSentinel = true,"compiled ranking cache reused within component context")
    ensure(SourceDisplayLabel({name:"[TB+] Torrentio 1080p",title:"Film X264"}) = "Torrentio 1080p · X264","resolution already in display name is not appended twice")
    ensure(SourceDisplayLabel({source:"iptv:1",name:"ThisIPTV · Inception (2010)",title:"HTTP stream"}) = "ThisIPTV","provider prefix excludes movie name and generic transport suffix")
    ensure(SourceDisplayLabel({source:"iptv:2",name:"Queens · Inception",title:"HTTP stream"}) = "Queens","provider prefix stays friendly without invented quality")
    compact = SourceDisplayLabel({source:"torrentio",name:"[TB+] Torrentio",title:"Inception.2010.1080p.BluRay.x264.TorrentGalaxy.mp4"+chr(10)+"7.96 GB TorrentGalaxy /"})
    ensure(compact = "Torrentio · 1080p · X264 · 7.96 GB","size and reported format replace filename body and decoration")
    originals = [{id:"one",displayName:"Queens",sourceEpoch:100},{id:"two",displayName:"Queens",sourceEpoch:100},{id:"other",displayName:"Unknown"}]
    distinct = DistinctSourceLabels(originals)
    ensure(distinct[0].displayName = "Queens · 1" and distinct[1].displayName = "Queens · 2" and distinct[2].displayName = "Unknown","identical labels get bounded display-only ordinals")
    ensure(originals[0].displayName = "Queens" and distinct[0].id = "one" and distinct[1].id = "two" and distinct[0].sourceEpoch = 100,"display polishing never changes original rows opaque IDs or age")
    clean = CleanSourceLabel("🎬 Café_日本語 Movie_file" + chr(10) + "1080p")
    ensure(instr(1,clean,"Café_日本語") = 0 and instr(1,clean,"Café") > 0 and instr(1,clean,"日本語") > 0,"cleanup keeps Unicode words")
    ensure(instr(1,clean,"🎬") = 0 and instr(1,clean,chr(10)) = 0,"cleanup removes emoji and controls")
    guide = CleanSourceLabel("Dr. Café_日本語 🔴️���",false)
    ensure(guide = "Dr. Café_日本語","guide cleanup strips decorations/replacement glyphs but preserves prose punctuation and Unicode")
    ensure(CleanSourceLabel("CNN Newsroom Sunday  ᴺᵉʷ",false) = "CNN Newsroom Sunday","actual CNN New suffix removed for display")
    ensure(CleanSourceLabel("World Sport  ᴸᶦᵛᵉ",false) = "World Sport","actual World Sport Live suffix removed for display")
    ensure(CleanSourceLabel("News ᴸᶦᵛᵉ ᴴᴰ",false) = "News","known trailing badge sequence removed")
    ensure(CleanSourceLabel("Café 日本語 ᴺᵉʷ edition ʷ",false) = "Café 日本語 ᴺᵉʷ edition ʷ","general Unicode modifier letters and internal tokens preserved")
    ensure(CleanSourceLabel("Newsᴺᵉʷ",false) = "Newsᴺᵉʷ","attached letters are not a standalone decoration token")
    ensure(CleanSourceLabel("News ᴺᵉʷ") = "News ᴺᵉʷ","filename mode unaffected by prose badge rule")
    ensure(instr(1,CleanSourceLabel("🇬🇧 🇮🇹",false),"English Italian") > 0,"supported flag glyphs retain language words")
    ensure(CleanSourceLabel("🇸🇪",false) = "[SE]","unmapped regional flags retain country code")
    fields = SourceFullDetails({name:"Provider",description:"Short description",filename:"Film.release.mkv",size_bytes:1073741824,reported_languages:["en","it","fr"]})
    ensure(instr(1,fields,"Film.release.mkv") > 0 and instr(1,fields,"Reported size: 1 GiB") > 0 and instr(1,fields,"Reported language: fr") > 0,"dedicated filename size and every reported language remain visible beyond compact row summaries")
    duplicate = SourceFullDetails({name:"Provider",title:"Movie" + chr(10) + "English · 4.2 GB",description:"Movie" + chr(10) + "English · 4.2 GB" + chr(10) + "Distinct release detail"})
    ensure(duplicate.split("English · 4.2 GB").count() = 2 and instr(1,duplicate,"Distinct release detail") > 0,"legacy title/description duplication is removed without losing distinct release details")
    full = SourceFullDetails({name:"Torrentio 🇬🇧",title:"Movie.1080p.WEB-DL.MULTI.x264.Release.mkv" + chr(10) + "🇮🇹 5.1 · 4.2 GB",description:"Café 日本語 full source details"})
    ensure(instr(1,full,"Movie.1080p.WEB-DL.MULTI.x264.Release.mkv") > 0,"full filename available in details without lossy title rewrite")
    ensure(instr(1,full,"English") > 0 and instr(1,full,"Italian") > 0 and instr(1,full,"Café 日本語") > 0,"all language and Unicode source details retained")
    ensure(instr(1,SourceDisplayLabel({name:"Source",title:"Digital cinema"}),"ITA") = 0,"language codes never match filename substrings")
    incoming = []
    for i = 0 to 109
        incoming.push({id:"t" + i.toStr(),source:"torrentio",name:"Torrentio",title:"4K HDR"})
    end for
    incoming.push(good)
    incoming.push(unknown)
    incoming.push({id:"iptv",source:"iptv",name:"Provider",title:"720p H264"})
    selected = FairSources([],incoming,"t0")
    ensure(selected.count() = 12,"group quotas prevent first hundred monopoly")
    counts = {}
    found = {}
    for each item in selected
        found[item.id] = true
        group = SourceGroup(item)
        if counts[group] = invalid then counts[group] = 0
        counts[group]++
    end for
    ensure(found.doesExist("good") and found.doesExist("unknown") and found.doesExist("iptv") and found.doesExist("t0"),"late providers best candidate and pin retained")
    ensure(counts.torrentio = 10,"at most ten per group")
    many = []
    for group = 0 to 9
        for i = 0 to 19
            many.push({id:group.toStr()+":"+i.toStr(),source:group.toStr(),name:"Source",title:"Movie"})
        end for
    end for
    ensure(FairSources([],many).count() = 80,"eight groups eighty total hard bound")
    stable = StableSourcePreference({source_addon_id:"org.example.addon",source_name:"Primary",source_fingerprint:string(64,"a")})
    ensure(stable.source_addon_id = "org.example.addon" and stable.source_name = "Primary","stable resume identity uses documented addon and source fields")
    ensure(StableSourcePreference({source:"Torrentio",source_name:"Primary"}).source_addon_id = invalid,"human provider source text never becomes addon identity")
    ensure(StableSourcePreference({source_addon_id:string(129,"a"),source_name:"Primary"}).source_addon_id = invalid,"addon identity honors backend 128-byte context bound")
    ensure(SourceMatchesPreference({addon_id:"org.example.addon",name:"Primary",source_fingerprint:string(64,"a")},stable),"current discovery may match canonical addon_id plus stable source name")
    ensure(not SourceMatchesPreference({addon_id:"org.example.addon",name:"Primary",source_fingerprint:string(64,"b")},stable),"same display name does not match a different release")
    ensure(not SourceMatchesPreference({addon_id:"org.example.addon",name:"Primary"},stable),"legacy name alone cannot autoplay a different source")
    ensure(FarBeforeEnd(12,2770),"short ENDLIST is not completion of known long movie")
    ensure(not FarBeforeEnd(2740,2770) and not FarBeforeEnd(12,0),"near end or unknown duration not guessed truncated")
    print "ROKU_SOURCE_POLICY_OK"
end sub
sub ensure(value as boolean, message as string)
    if not value then throw message
end sub
