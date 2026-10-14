sub Main()
    genre = {id:"genre",label:"Genre",kind:"MultiChoice",required:true,maximum_selections:2,choices:[{value:"A&B",label:"Action"},{value:"C,D",label:"Drama"},{value:"other",label:"Other"}]}
    control = {id:"sort",label:"Sort",kind:"SingleChoice",required:false,maximum_selections:invalid,choices:[{value:"rank",label:"Ranking"}]}
    catalogs = []
    for each id in [1,2]
        catalogs.push({id:"top",name:"Popular",type:"movie",connection_id:"addon:"+id.toStr(),connection_name:"Friendly provider",addon_id:id,controls:[genre,control]})
    end for
    m.reply = {provider_id:"stremio",media_types:["movie","series"],controls:[],catalogs:catalogs,discovery:{availability:"Available"}}
    response = EngineContentRequest({base:"https://fixture.invalid",path:"/api/v3/discovery-controls?type=movie"},{ok:false},"GET")
    check(response.ok and response.data.catalogs.count() = 2,"canonical controls request projects every owner")
    check(m.path = "/api/v3/discovery-controls?type=movie","controls do not use Home/bootstrap")
    first = response.data.catalogs[0]
    check(first.connection_id = "addon:1" and first.addon_id = 1,"catalog owner is retained")
    check(first.controls[0].maximum_selections = 2,"host selection cap survives")
    check(DiscoveryMissingControl(first,"","",{},{}) = "Genre","required vectors prevent catalog IO")
    check(DiscoveryMissingControl(first,"","",{},{genre:["A&B","C,D"]}) = "","valid array is accepted")
    check(DiscoveryMissingControl(first,"","",{},{genre:["A&B","C,D","other"]}) = "Genre","over-cap array is refused")
    check(DiscoveryControlLabel(control,["rank"]) = "Ranking","friendly choice label differs from transport value")
    check(DiscoveryControlLabel(genre,["A&B","C,D"]) = "2 selected","multiple values use a friendly count")
    labels = DiscoveryCatalogLabels(response.data.catalogs)
    check(labels[0] = "Friendly provider · Popular (1)" and labels[1] = "Friendly provider · Popular (2)","identical friendly names are distinguishable")
    values = DiscoveryQueryValues({genre:["A&B","C,D"],empty:[]})
    check(values.count() = 1 and values[0].values[1] = "C,D","one lossless vector per nonempty filter")
    m.reply = {provider_id:"simkl",media_types:["movie","series"],catalogs:[],controls:[control],discovery:{availability:"Available"}}
    response = EngineContentRequest({base:"https://fixture.invalid",path:"/api/v3/discovery-controls?type=series"},{ok:false},"GET")
    check(response.data.catalogs.count() = 1 and response.data.catalogs[0].id = "","catalog-less host has an aggregate without fabricated catalog ID")
    m.reply.media_types = ["custom/type"]
    response = EngineContentRequest({base:"https://fixture.invalid",path:"/api/v3/discovery-controls?type=custom%2Ftype"},{ok:false},"GET")
    check(response.data.catalogs[0].type = "custom/type","encoded host media type is decoded before projection")
    m.reply.discovery.availability = "RequiresAuth"
    response = EngineContentRequest({base:"https://fixture.invalid",path:"/api/v3/discovery-controls?type=series"},{ok:false},"GET")
    check(response.data.catalogs.count() = 0,"unavailable provider does not fabricate controls")
    selected = ["A&B"]
    draft = ChoiceInitialSelection([{value:"A&B"},{value:"C,D"},{value:"other"}],selected,2)
    draft = ChoiceToggle(draft,"C,D",2)
    check(selected.count() = 1 and draft.count() = 2,"draft does not mutate query")
    draft = ChoiceToggle(draft,"other",2)
    check(draft.count() = 2 and not ChoiceHasValue(draft,"other"),"sheet enforces cap")
    draft = ChoiceToggle(draft,"A&B",2)
    check(draft.count() = 1 and draft[0] = "C,D","sheet can deselect at cap")
    print "ROKU_ENGINE_DISCOVERY_OK"
end sub

function HttpRequestRaw(request as object, result as object, method as string, sanitize as boolean) as object
    m.path = request.path
    return {ok:true,data:m.reply}
end function

sub check(value as boolean, label as string)
    if not value then throw label
end sub
