sub Main()
    cells = EpgCells([{start:70,end:160,title:"First"},{start:160,end:200,title:"Second"},{start:140,end:155,title:"Overlapping"},{start:250,end:300,title:"Later"}],100,400)
    check(cells.count()=5,"overlap suppressed, real holes retained")
    check(cells[0].start=100 and cells[0].end=160,"clip started programme")
    check(cells[2].missing and cells[2].start=200 and cells[2].end=250,"gap is explicitly missing")
    check(EpgCellAt(cells,160)=1,"exact boundary selects next programme")
    geometry = EpgGeometry(cells[0],100,300,900)
    check(geometry.x=0 and geometry.width=180,"duration controls proportional width")
    check(EpgCells([],100,400)[0].missing,"missing schedule keeps watchable slot")
    print "EPG_POLICY_OK"
end sub
sub check(value as boolean, message as string)
    if not value then throw message
end sub
