"""Run the real native profile editor and account mutation handlers."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
def routine(file,start,end='end sub'):
 text=(root/file).read_text(); a=text.index(start); return text[a:text.index(end,a)+len(end)]
source='\n'.join(routine('components/AccountScene.brs',x,e) for x,e in [
 ('sub accountUseProfiles(', 'end sub'),('sub accountProfileAction(', 'end sub'),('sub accountManageProfiles()', 'end sub'),
 ('sub accountEditorAction()', 'end sub'),('sub accountFinishProfileSetup(', 'end sub'),
 ('function accountResponse(', 'end function'),('sub accountSubmitParentPin(', 'end sub'),
 ('sub accountDeleteConfirmed(', 'end sub')])+'\n'+(root/'source/Util.brs').read_text()+'\n'+(root/'source/AccountPolicy.brs').read_text()+'''
sub Main()
 m.accountEpoch=8:m.config={last_profile_id:"1"}:m.profile="1":m.status={text:""}
 m.profileEditor={visible:true,saving:false,callFunc:noop}:m.pendingProfile=invalid
 m.canCreateProfile=true:m.switchingProfile=true
 accountUseProfiles([{id:"1",name:"Owner",setup_complete:true},{id:"2",name:"Second",setup_complete:true}])
 if m.values.count()<>2 then throw "profile cards contain action tiles"
 if m.values[0].is_primary<>true or m.values[1].is_primary<>false then throw "primary identification wrong"
 m.switchingProfile=true
 accountUseProfiles([{id:"1",name:"Secondary",setup_complete:true,is_primary:false},{id:"2",name:"Primary",setup_complete:true,is_primary:true}])
 if m.values[0].is_primary<>false or m.values[1].is_primary<>true then throw "server primary flag was overwritten"
 accountProfileAction({action:"manageprofiles"})
 if m.managingProfiles<>true or m.opened<>true then throw "manage action missing"
 accountProfileAction({id:"2",name:"Second",presentation_complete:true})
 if m.edited.id<>"2" then throw "manage selected profile instead of editing"
 accountProfileAction({action:"newprofile"})
 if m.edited<>invalid then throw "add failed"
 m.profileDraft={name:" Renamed ",avatar_style:"disney",avatar_choice:2,profile:{id:"2"}}
 accountFinishProfileSetup("disney")
 if m.sent.method<>"PATCH" or m.sent.path<>"/api/profiles/2" or m.sent.body.name<>"Renamed" then throw "edit did not patch identity"
 m.authBusy=false:m.profileDraft.profile=invalid
 accountFinishProfileSetup("disney")
 if m.sent.method<>"POST" or m.sent.path<>"/api/profiles" then throw "create route wrong"
 original={method:"POST",path:"/api/profiles",body:{name:"Draft"},account_epoch:8}
 accountResponse("auth:newprofile",{ok:false,status:403,auth_code:"parent_required"},original)
 if m.parentAction<>"profilemutation" or m.keyboardKind<>"parentpin" then throw "restricted create lacks parent gate"
 accountSubmitParentPin({accepted:false,text:""})
 if m.profileDraft.name<>" Renamed " or m.parentAction<>"" or m.profileMutation<>invalid then throw "PIN cancel lost draft"
 accountResponse("auth:newprofile",{ok:false,status:403,auth_code:"parent_required"},original)
 accountResponse("auth:parentunlock",{ok:true,data:{unlocked:true}},{account_epoch:8,body:{pin:"1234"}})
 if m.sent.path<>"/api/profiles" or m.sent.body.name<>"Draft" then throw "parent unlock did not retry mutation"
 m.profileDraft={profile:{id:"1",is_primary:true}}:m.top={dialog:{buttonSelected:1}}
 m.sent={path:"unchanged"}:accountDeleteConfirmed()
 if m.sent.path<>"unchanged" then throw "primary delete allowed"
 m.profileDraft={profile:{id:"2",is_primary:false}}:m.top.dialog={buttonSelected:0}
 accountDeleteConfirmed()
 if m.sent.path<>"unchanged" then throw "cancel deleted profile"
 m.top.dialog={buttonSelected:1}:accountDeleteConfirmed()
 if m.sent.method<>"DELETE" or m.sent.path<>"/api/profiles/2" then throw "confirmed delete missing"
 m.profile="2":m.config.refresh_token="paired"
 accountResponse("auth:deleteprofile",{ok:true,data:{}},{account_epoch:8})
 if m.profile<>"" or m.config.refresh_token<>"paired" or m.opened<>true then throw "selected deletion signed out device"
 print "PROFILE_MANAGEMENT_RUNTIME_OK"
end sub
sub noop(name)
end sub
sub accountOpenProfiles()
 m.opened=true
end sub
sub accountShowProfileGrid(values)
 m.values=values
end sub
sub accountStartProfileSetup(item)
 m.edited=item
end sub
sub accountChoose(item)
 throw "unexpected profile selection"
end sub
sub request(method,path,body,tag)
 m.sent={method:method,path:path,body:body,tag:tag}
end sub
sub keyboard(kind,title,value)
 m.keyboardKind=kind
end sub
sub accountClearRememberedProfile()
 m.profile="":m.config.last_profile_id=""
end sub
'''
with tempfile.TemporaryDirectory() as directory:
 fixture=Path(directory)/'profiles.brs';fixture.write_text(source)
 result=subprocess.run([os.environ.get('VIPTV_BRS_CLI','brs-cli'),str(fixture)],capture_output=True,text=True,timeout=30)
 print(result.stdout,end='');print(result.stderr,end='')
 if result.returncode or 'PROFILE_MANAGEMENT_RUNTIME_OK' not in result.stdout:raise SystemExit(1)

editor='\n'.join(routine('components/ProfileEditor.brs',x,e) for x,e in [
 ('sub refresh()', 'end sub'),('sub selected()', 'end sub'),('function buttons(', 'end function')])+'''
sub Main()
 title={text:""}
 m.top={draft:{name:"Second",avatar_url:"",editing:true,profile:{id:"2",is_primary:false}},saving:false,action:"",findNode:findTitle,titleNode:title}
 m.name={}:m.actions={}:m.avatar={}
 refresh()
 if title.text<>"Edit profile" or m.actions.numColumns<>3 then throw "editor title or three-column geometry wrong"
 if m.actions.content.getChild(0).title<>"Save" or m.actions.content.getChild(2).title<>"Delete profile" then throw "edit actions missing"
 m.actions.itemSelected=2:selected()
 if m.top.action<>"delete" then throw "delete action missing"
 m.top.draft={name:"Owner",avatar_url:"",editing:true,profile:{id:"1",is_primary:true}}
 refresh()
 if m.actions.numColumns<>2 or m.actions.content.getChildCount()<>2 then throw "primary shows delete"
 m.top.draft={name:"",avatar_url:"",profile:invalid}:refresh()
 if title.text<>"Add a profile" or m.actions.content.getChild(0).title<>"Create profile" then throw "creation title/action wrong"
 m.top.saving=true:m.top.action="":m.actions.itemSelected=0:selected()
 if m.top.action<>"" then throw "duplicate save accepted"
 print "PROFILE_EDITOR_RUNTIME_OK"
end sub
function findTitle(id)
 return m.titleNode
end function
'''
with tempfile.TemporaryDirectory() as directory:
 fixture=Path(directory)/'editor.brs';fixture.write_text(editor)
 result=subprocess.run([os.environ.get('VIPTV_BRS_CLI','brs-cli'),str(fixture)],capture_output=True,text=True,timeout=30)
 print(result.stdout,end='');print(result.stderr,end='')
 if result.returncode or 'PROFILE_EDITOR_RUNTIME_OK' not in result.stdout:raise SystemExit(1)

layout='\n'.join(routine('components/AccountScene.brs',x,e) for x,e in [
 ('sub accountShowProfileGrid(', 'end sub'),('sub accountRenderProfilePage()', 'end sub'),
 ('sub accountFillProfileButtons(', 'end sub'),('sub accountProfileButtonSelected()', 'end sub'),
 ('sub accountProfilePageSelected()', 'end sub'),('function accountProfileKey(', 'end function')])+'\n'+(root/'source/Util.brs').read_text()+'\n'+(root/'source/AccountPolicy.brs').read_text()+'''
sub Main()
 m.heading={font:{}}:m.status={}
 m.profileGrid=grid():m.profileActions=grid():m.profilePages=grid():m.profilePageLabel={}
 m.canCreateProfile=true:m.managingProfiles=true:m.profileFocusId="12"
 profiles=[]
 for i=1 to 12
  profiles.push({id:i.toStr(),name:"Person "+i.toStr()})
 end for
 accountShowProfileGrid(profiles)
 if m.profilePage<>2 or m.items.count()<>2 or m.items[1].id<>"12" or m.profileGrid.jumpToItem<>1 then throw "last profile was unreachable after editor return"
 if m.profileActions.content.getChildCount()<>1 or m.profileActions.content.getChild(0).title<>"Done" then throw "capacity should hide Add but retain Done"
 if m.profileGrid.translation[1]+210>=m.profileActions.translation[1] then throw "actions overlap people"
 if not m.profilePages.visible or m.profilePageLabel.text<>"3 / 3" then throw "twelve profiles lack bounded pages"
 seen={}
 for pageIndex=0 to 2
  m.profilePage=pageIndex:accountRenderProfilePage()
  if m.items.count()>5 then throw "too many avatar cards rendered"
  for each item in m.items
   if Txt(item.action)<>"" then throw "action masquerades as person"
   seen[item.id]=true
  end for
 end for
 if seen.count()<>12 then throw "paging dropped profiles"
 m.profilePages.itemSelected=0:accountProfilePageSelected()
 if m.profilePage<>1 or m.profileFocusId<>"6" then throw "previous page lost canonical focus"
 accountShowProfileGrid(profiles)
 if m.profilePage<>1 then throw "chooser return reset page"
 ' Add/cancel rebuilds the chooser: remember the actual person left via Down.
 m.profilePage=1:accountRenderProfilePage()
 m.profileGrid.itemFocused=3:m.profileGrid.focused=true
 if not accountProfileKey("down") then throw "could not leave second-page person"
 accountShowProfileGrid(profiles)
 if m.profilePage<>1 or m.profileGrid.jumpToItem<>3 or m.profileFocusId<>"9" then throw "Add cancel lost exact second-page person"
 m.profilePage=2:accountRenderProfilePage()
 m.profileGrid.itemFocused=1:m.profileGrid.focused=true
 if not accountProfileKey("down") then throw "could not leave third-page person"
 accountShowProfileGrid(profiles)
 if m.profilePage<>2 or m.profileGrid.jumpToItem<>1 or m.profileFocusId<>"12" then throw "action return lost exact third-page person"
 accountShowProfileGrid([profiles[0],profiles[1]])
 if m.profileButtons.count()<>2 or m.profileButtons[0].action<>"newprofile" or m.profileButtons[1].action<>"profilesdone" then throw "separate management buttons wrong"
 if m.profilePages.visible then throw "unneeded pager visible"
 m.profileActions.itemSelected=0:accountProfileButtonSelected()
 if m.action<>"newprofile" then throw "Add button unreachable"
 m.managingProfiles=false:accountRenderProfilePage()
 if m.profileButtons[1].action<>"manageprofiles" then throw "chooser lacks normal Manage button"
 m.profileGrid.focused=true:m.profileActions.focused=false
 if not accountProfileKey("down") or m.profileActions.focused<>true then throw "Down cannot reach buttons"
 m.profileGrid.focused=false
 if not accountProfileKey("up") or m.profileGrid.focused<>true then throw "Up cannot return to people"
 m.profileGrid.focused=false:m.profileActions.focused=true:m.profilePages.visible=true
 if not accountProfileKey("down") or m.profilePages.focused<>true then throw "pager unreachable"
 print "PROFILE_LAYOUT_RUNTIME_OK"
end sub
function grid()
 return {visible:false,focused:false,setFocus:focus,hasFocus:focused}
end function
sub focus(value)
 m.focused=value
end sub
function focused()
 return m.focused
end function
sub rows(title,values,mode,message)
 m.items=values:m.mode=mode
end sub
sub uiFocusChanged()
end sub
sub accountProfileAction(item)
 m.action=item.action
end sub
'''
with tempfile.TemporaryDirectory() as directory:
 fixture=Path(directory)/'layout.brs';fixture.write_text(layout)
 result=subprocess.run([os.environ.get('VIPTV_BRS_CLI','brs-cli'),str(fixture)],capture_output=True,text=True,timeout=30)
 print(result.stdout,end='');print(result.stderr,end='')
 if result.returncode or 'PROFILE_LAYOUT_RUNTIME_OK' not in result.stdout:raise SystemExit(1)
