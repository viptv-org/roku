' Injected into EpgGrid only in a disposable preview project.
sub epgCheck(value as boolean, message as string)
    if not value then throw message
end sub
sub runChecks()
    now = CreateObject("roDateTime").asSeconds()
    icon = m.rowViews[0].icon
    epgRender()
    epgCheck(icon.isSameNode(m.rowViews[0].icon),"focus repaint preserves logo node identity")
    epgCheck(not m.day.visible,"no redundant local-time label")
    epgCheck(instr(1,m.selection.text,"Cartoon Network")=0,"selected programme is not duplicated with channel name")
    onKeyEvent("right",true)
    epgCheck(m.selectedCell.start>now,"right selects an upcoming programme")
    onKeyEvent("OK",true)
    epgCheck(m.details.visible,"future OK opens details")
    epgCheck(m.top.watch=invalid,"future details must not silently tune")
    onKeyEvent("back",true)
    epgCheck(not m.details.visible,"Back dismisses details")
    time = m.anchor
    onKeyEvent("down",true)
    epgCheck(m.row=1 and m.anchor=time,"vertical navigation preserves chosen airtime")
    onKeyEvent("instantreplay",true)
    epgCheck(m.followNow and m.anchor>=now,"Replay returns to live time")
    onKeyEvent("OK",true)
    epgCheck(m.top.watch.id="demo1","watch uses exact West channel identity")
    old = m.cache.demo1.programs
    m.top.guide = {id:"demo1",ok:false,programs:[]}
    epgGuide()
    epgCheck(m.cache.demo1.programs.count()=old.count(),"failed refresh preserves previous schedule")
    m.menuFocus = true
    onKeyEvent("down",true)
    onKeyEvent("OK",true)
    epgCheck(m.top.route.filter.id="favorites","My channels requests profile favorites")
    epgCheck(m.channels.count()=0,"filter change cannot display old channel rows")
    print "EPG_NAVIGATION_OK"
end sub
