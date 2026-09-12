sub Main()
    m.imageScale = 1
    url = "https://image.tmdb.org/t/p/original/example.jpg"
    small = ImageUrl(url,256,144)
    check(instr(1,small,"&w=256&h=144")>0,"HD card size")
    check(instr(1,small,"w500")>0,"small source bucket")
    check(instr(1,small,"&q=85")>0,"card quality")
    m.imageScale = 1.5
    hero = ImageUrl(url,1280,720,true)
    check(instr(1,hero,"&w=1920&h=1080")>0 and instr(1,hero,"&q=95")>0,"large high quality")
    small = ImageUrl(small,256,144)
    check(instr(1,small,"&w=384&h=216")>0 and instr(1,small,"wsrv.nl%2F")=0,"no nested proxy")
    for each private in ["http://192.168.1.2/image.jpg","https://addon.invalid/token/image.jpg","https://image.tmdb.org/t/p/w500/image.jpg?token=private","pkg:/images/mark.png","https://image.tmdb.org.evil.invalid/image.jpg"]
        check(ImageUrl(private,256,144)=private,"private/original URLs stay local")
    end for
    check(instr(1,ImageUrl("https://i.imgur.com/logo.png",112,73,false,true),"output=png")>0,"logo transparency")
    print "IMAGE_POLICY_OK"
end sub
sub check(ok as boolean,label as string)
    if not ok then throw label
end sub
