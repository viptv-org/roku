' Focused checks for NEW presentation adapters, not an auth/playback regression suite.
sub main()
    episode = {type:"series",id:"tt9288030:2:1",series_id:"tt9288030",season:2,episode:1,position:38}
    if PresentationMetadataId(episode) <> "tt9288030" then stop
    if episode.id <> "tt9288030:2:1" or episode.position <> 38 then stop
    opaque = {type:"series",id:"addon:opaque:episode"}
    if PresentationMetadataId(opaque) <> opaque.id then stop
    movie = {type:"movie",id:"addon:movie:1",series_id:"tt9288030"}
    if PresentationMetadataId(movie) <> movie.id then stop
    art = {poster:"https://example.test/poster.jpg",backdrop:"",background:"https://example.test/still.jpg"}
    if PresentationBackdrop(art) <> art.background then stop
    art.backdrop = art.poster
    if PresentationBackdrop(art) <> art.background then stop
    art.background = art.poster
    if PresentationBackdrop(art) <> "" then stop
    if PresentationBackdrop({background:"https://image.tmdb.org/t/p/w500/landscape.jpg"}) <> "https://image.tmdb.org/t/p/w1280/landscape.jpg" then stop
    history = [{id:"ep2",series_id:"show",type:"series",position:200,duration:2000},{id:"ep1",series_id:"show",type:"series",position:500,duration:2000},{id:"live",type:"live",position:0,duration:0}]
    resumable = ContinueWatchingItems(history)
    if resumable.count() <> 1 or resumable[0].id <> "ep2" then stop
    if LiveOnlyItems(history).count() <> 1 then stop
    if FavoriteArtwork({type:"live",logo:"https://example.test/logo.png"}) <> "https://example.test/logo.png" then stop
    print "PASS: presentation metadata and backdrop adapters"
end sub
