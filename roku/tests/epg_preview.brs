sub init()
    m.grid = m.top.findNode("grid")
    m.grid.callFunc("open","preview")
    m.grid.categories = [{id:"kids",name:"Kids"},{id:"sports",name:"Sports"},{id:"news",name:"News"},{id:"movies",name:"Movies"}]
    channels = []
    names = ["Cartoon Network East","Cartoon Network West","HGTV","HBO","FOX Sports","CNN"]
    for i = 0 to 5
        channels.push({id:"demo"+i.toStr(),name:names[i],type:"live"})
    end for
    m.grid.data = {channels:channels,total:6,offset:0}
    now = CreateObject("roDateTime").asSeconds()
    startAt = (now \ 1800)*1800
    for i = 0 to 4
        titles = ["The Amazing World of Gumball","Teen Titans Go!","House Hunters","The Movie Hour","Live Basketball"]
        programs = [{start:startAt-600,end:startAt+1800,title:titles[i],description:"A full programme description is available here. Future listings provide details; Watch always tunes the channel live."},{start:startAt+1800,end:startAt+3600,title:"Coming up next"},{start:startAt+3600,end:startAt+9000,title:"Evening highlights"}]
        if i=3 then programs = [{start:startAt-1800,end:startAt+5400,title:"The Movie Hour"}]
        m.grid.guide = {id:"demo"+i.toStr(),ok:true,programs:programs}
    end for
    m.grid.guide = {id:"demo5",ok:false,programs:[]}
    m.grid.setFocus(true)
end sub
