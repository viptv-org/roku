' Regression for native ContentNode id collision and chooser-to-Home visibility.
sub Main()
    m.failures = 0
    m.config = {base:"https://tv.example",access_token:"access",refresh_token:"refresh",last_profile_id:"",account_id:"account",auth_version:3}
    m.accountEpoch = 4
    m.generation = 2
    m.requestSequence = 0
    m.queue = []
    m.tasks = []
    m.authBusy = false
    m.status = CreateObject("roSGNode","Label")
    m.identity = CreateObject("roSGNode","Label")
    m.sidebar = invalid
    m.poll = CreateObject("roSGNode","Timer")
    m.budgetTimer = invalid
    m.liveEpgTimer = invalid
    m.favoriteBusy = false
    m.cache = {}
    m.cacheKeys = []
    m.views = []
    m.homeData = invalid
    m.homeRoot = invalid
    m.homePosition = [0,0]
    m.homeKeyValue = ""
    m.pendingProfile = invalid
    m.profileDraft = invalid
    m.searchFocusPending = false
    m.profile = ""

    ' Use a real native ContentNode whose transport fields deliberately disagree with
    ' the canonical model. Roku OS field population differs from the simulator, so
    ' the invariant is that selection never trusts this presentation node's id.
    root = CreateObject("roSGNode","ContentNode")
    child = root.createChild("ContentNode")
    child.addFields({name:"Node copy",avatar_url:"",presentation_complete:true})
    child.id = "wrong-native-id"
    check(child.hasField("id") and child.hasField("presentation_complete"), "fixture uses real native and custom SceneGraph fields")
    grid = CreateObject("roSGNode","MarkupGrid")
    grid.content = root
    grid.itemSelected = 0
    grid.visible = true
    m.profileGrid = grid

    ' The canonical model must be used instead of reconstructing the native node.
    m.items = [{id:"7",name:"vynxc",avatar_url:"https://api.dicebear.com/10.x/critters/png?seed=opaque&size=256",presentation_complete:true}]
    profileGridSelected()
    check(m.pendingProfile <> invalid and Txt(m.pendingProfile.id) = "7", "selected profile retains canonical model id")
    check(m.queue.count() = 1 and m.queue[0].path = "/api/auth/profile", "selection queues canonical profile endpoint")
    check(m.queue[0].body.profile_id = 7, "selection POST sends numeric canonical profile id")
    check(m.queue[0].account_epoch = m.accountEpoch, "selection request uses post-reset account epoch")

    ' A successful selection must be able to reveal Home rather than leave chooser above it.
    m.sourceText = invalid
    m.standardList = CreateObject("roSGNode","Group")
    m.posterGrid = CreateObject("roSGNode","Group")
    m.sourceList = CreateObject("roSGNode","Group")
    m.list = m.standardList
    m.homePanel = CreateObject("roSGNode","Group")
    m.heading = CreateObject("roSGNode","Label")
    m.footer = CreateObject("roSGNode","Label")
    m.art = CreateObject("roSGNode","Poster")
    m.detailTitle = CreateObject("roSGNode","Label")
    m.detailInfo = CreateObject("roSGNode","Label")
    m.description = CreateObject("roSGNode","Label")
    m.detailPanel = CreateObject("roSGNode","Group")
    m.profileGrid.visible = true
    homeVisible(true)
    check(m.homePanel.visible and not m.profileGrid.visible, "Home transition hides profile chooser overlay")
    check(not m.heading.visible and not m.footer.visible, "Home owns heading and footer visibility")

    if m.failures > 0 then stop
    print "ROKU_PROFILE_SELECTION_RUNTIME_OK"
end sub

sub check(ok as boolean, message as string)
    if ok
        print "PASS "; message
    else
        print "FAIL "; message
        m.failures++
    end if
end sub
