"""Exercise actual PIN entry masking/cancellation and profile-unlock handoff."""
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
def routine(file,start,end):
 text=(root/file).read_text();a=text.index(start);return text[a:text.index(end,a)+len(end)]
source=routine('components/TextEntry.brs','sub updateValue()','end sub')+'\n'+routine('components/TextEntry.brs','sub finishEntry(','end sub')+'\n'+routine('components/AccountScene.brs','function accountResponse(','end function')+'\n'+routine('components/AccountScene.brs','sub accountSubmitParentPin(','end sub')+'\n'+routine('components/AccountScene.brs','sub accountSignOut(','end sub')+'\n'+(root/'source/Util.brs').read_text()+'''
sub Main()
 m.label={text:""}:m.keys={text:"1234"}
 m.top={secret:true,value:"1234",findNode:findLabel}
 updateValue()
 if m.label.text<>"****" then throw "PIN exposed on screen"
 finishEntry(false)
 if m.top.result.text<>"" or m.keys.text<>"" or m.top.value<>"" then throw "cancel retained PIN"
 m.keys.text="5678":finishEntry(true)
 if m.top.result.text<>"5678" or m.keys.text<>"" then throw "accepted PIN handoff failed"
 m.accountEpoch=3:m.pendingProfile={id:"2"}:m.status={text:""}
 accountResponse("auth:profile",{ok:false,auth_code:"parent_required",status:403},{account_epoch:3})
 if m.keyboardKind<>"parentpin" then throw "protected switch did not request PIN"
 accountSubmitParentPin({accepted:true,text:"1234"})
 if m.sentPath<>"/api/parent/unlock" or m.sentBody.pin<>"1234" then throw "PIN did not reach unlock endpoint"
 origin={account_epoch:3,body:{pin:"1234"}}
 accountResponse("auth:parentunlock",{ok:true,data:{unlocked:true}},origin)
 if m.chosen<>"2" or origin.body<>invalid then throw "unlock lost target or retained PIN"
 m.chosen="":m.pendingProfile={id:"3"}
 accountResponse("auth:parentunlock",{ok:true,data:{unlocked:true}},{account_epoch:2})
 if m.chosen<>"" then throw "stale unlock switched profile"
 accountSubmitParentPin({accepted:false,text:"5678"})
 if m.pendingProfile<>invalid or m.opened<>true then throw "cancel did not return to chooser"
 m.profile="kid":m.config={access_token:"fixture",refresh_token:"fixture"}
 accountResponse("auth:logout",{ok:false,auth_code:"parent_required",status:403},{account_epoch:3})
 if m.parentAction<>"logout" or m.config.access_token<>"fixture" then throw "protected logout discarded session"
 accountSubmitParentPin({accepted:false,text:""})
 if m.profile<>"kid" or m.settingsShown<>true or m.parentAction<>"" then throw "cancel logout lost kids session"
 accountResponse("auth:logout",{ok:false,auth_code:"parent_required",status:403},{account_epoch:3})
 accountResponse("auth:parentunlock",{ok:true,data:{unlocked:true}},{account_epoch:3})
 if m.sentPath<>"/api/auth/logout" or m.config.access_token<>"fixture" then throw "unlock did not retry logout before clearing credentials"
 accountResponse("auth:logout",{ok:true,data:{}},{account_epoch:3})
 if m.config.access_token<>"" or m.paired<>true then throw "confirmed logout did not finish"
 print "PARENT_PIN_RUNTIME_OK"
end sub
sub keyboard(kind,title,value)
 m.keyboardKind=kind
end sub
sub request(method,path,body,tag)
 m.sentPath=path:m.sentBody=body
end sub
sub accountChoose(item)
 m.chosen=item.id
end sub
sub accountCancelCredentials()
 m.config.access_token=""
end sub
sub accountPair()
 m.paired=true
end sub
sub showSettings()
 m.settingsShown=true
end sub
sub accountOpenProfiles()
 m.opened=true
end sub
function findLabel(id)
 return m.label
end function
'''
# AA method m scope differs from SceneGraph component; return explicit shared label.
source=source.replace('m.top={secret:true,value:"1234",findNode:findLabel}', 'm.top={secret:true,value:"1234",findNode:findLabel,label:m.label}')
with tempfile.TemporaryDirectory() as directory:
 fixture=Path(directory)/'parent.brs';fixture.write_text(source)
 result=subprocess.run([os.environ.get('VIPTV_BRS_CLI','brs-cli'),str(fixture)],capture_output=True,text=True,timeout=30)
 print(result.stdout,end='');print(result.stderr,end='')
 if result.returncode or 'PARENT_PIN_RUNTIME_OK' not in result.stdout:raise SystemExit(1)
