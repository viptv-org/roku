sub Main()
 caps={max_height:1080,hevc_sdr:false}
 plain={title:"Movie 1080p x264 English"}
 dub={title:"Movie 1080p x264 English Dubbed"}
 multi={title:"Movie 1080p x264 Multi Audio"}
 subs={title:"Movie 1080p x264",description:"Audio: Japanese | Subtitles: English"}
 ensure(SourceMatch(dub,caps,{}).rank<SourceMatch(plain,caps,{}).rank,"English dub must outrank plain English text")
 ensure(SourceMatch(multi,caps,{}).rank<SourceMatch(plain,caps,{}).rank,"multi audio outweighs a bare English token")
 ensure(SourceMatch(subs,caps,{}).rank>SourceMatch(plain,caps,{}).rank,"subtitle English is not audio evidence")
 ensure(not SourceMatch(subs,caps,{}).best,"English subtitles cannot earn best language match")
 ensure(instr(1,SourceBadges(plain,invalid),"ENGLISH AUDIO HINT")=0,"weak text must not label English audio")
 ensure(SourceMatch({title:"1080p x264 English dubbed | Japanese subtitles"},caps,{}).rank=SourceMatch(dub,caps,{}).rank,"subtitle clause must not erase explicit dub evidence")
 ensure(SourceMatch({title:"1080p x264 Spanish audio"},caps,{audio_language:"es"}).best,"preferred language scoring stays supported")
 ensure(SourceMatch({title:"1080p x264 English English English"},caps,{}).rank=SourceMatch(plain,caps,{}).rank,"repeated words cannot inflate score")
 ensure(SourceMatch({title:"1080p x264",reported_languages:["en"]},caps,{}).rank>SourceMatch(dub,caps,{}).rank,"unverified addon language does not beat explicit dub")
 ensure(SourceLanguageScore({description:"Japanese audio English subtitles"})=0,"inline subtitle language must not leak into audio scoring")
 ensure(SourceLanguageScore({description:"English audio Japanese subtitles"})>=4,"inline actual English audio stays strong")
 print "AUDIO_SCORE_OK"
end sub
sub ensure(value as boolean,message as string)
 if not value then throw message
end sub
