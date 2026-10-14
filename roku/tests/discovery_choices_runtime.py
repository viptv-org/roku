"""Actual discovery and sheet handlers: draft ownership, Apply, Cancel and paging."""
from pathlib import Path
import subprocess
import tempfile
from brs_cli import brs_command

root = Path(__file__).resolve().parents[1]

def routine(file, start, end):
    source = (root / file).read_text()
    offset = source.index(start)
    return source[offset:source.index(end, offset) + len(end)]

source = '\n'.join([
    routine('components/DiscoverScene.brs', 'sub browse(', 'end sub'),
    routine('components/DiscoverScene.brs', 'function acknowledgementMayFocus', 'end function'),
    routine('components/PresentationScene.brs', 'sub uiChoiceSelected(', 'end sub'),
    routine('components/UiChoice.brs', 'sub choose()', 'end sub'),
    routine('components/UiChoice.brs', 'sub choiceAction()', 'end sub'),
    routine('components/UiChoice.brs', 'sub choiceDismiss()', 'end sub'),
    routine('components/UiChoice.brs', 'function onKeyEvent(', 'end function'),
    routine('components/PresentationDiscoveryScene.brs', 'sub uiDiscoveryControl(', 'end sub'),
    routine('components/PresentationDiscoveryScene.brs', 'sub uiSetDiscoveryScalar(', 'end sub'),
])
fixture = '''
sub Main()
 m.generation=9:m.choiceGeneration=9:m.calls=[]:m.uiReady=false:m.discoverActive=true
 m.discoverType="movie":m.search="":m.discoverGenre="":m.discoverExtras={}:m.discoverVectors={}
 m.catalog={id:"top",type:"movie",addon_id:2,connection_id:"addon:2",controls:[]}
 m.status={}:m.discoverFilters={setFocus:fakeFocus}:m.choicePanel={}:m.mode="browse"
 control={id:"genre",label:"Genre",kind:"MultiChoice",required:true,maximum_selections:2,choices:[]}
 for i=0 to 39
  control.choices.push({value:"g"+i.toStr(),label:"Genre "+i.toStr()})
 end for
 m.catalog.controls=[control]
 browse("movie",0)
 if m.calls.count()<>0 then throw "required filter fetched before input"
 uiDiscoveryControl(control)
 if not m.choicePanel.model.multiple or m.choicePanel.model.items.count()<>40 then throw "multiple choices truncated or wrong sheet"
 m.items=m.choicePanel.model.items:m.draft=[]:m.multiple=true:m.maximum=2:m.required=true
 m.choices={itemSelected:0,itemFocused:35,hasFocus:fakeHasFocus,setFocus:fakeFocus,focused:true}
 m.actions={itemSelected:1,hasFocus:fakeHasFocus,setFocus:fakeFocus,focused:false}
 m.top={visible:true,nodes:{description:{}},findNode:fakeFind}
 choose()
 m.choices.itemSelected=35:choose()
 m.choices.itemSelected=39:choose()
 if m.draft.count()<>2 or m.calls.count()<>0 or m.discoverVectors.count()<>0 then throw "draft cap or query isolation failed"
 if not onKeyEvent("right",true) or m.actions.jumpToItem<>1 or not m.actions.focused then throw "Apply unreachable without scrolling all choices"
 m.choices.focused=false
 if not onKeyEvent("up",true) or m.choices.jumpToItem<>35 then throw "return from footer lost choice position"
 choiceAction()
 if m.calls.count()<>0 or m.top.visible then throw "sheet submitted directly instead of producing an Apply event"
 m.payload=m.top.selection
 uiChoiceSelected({payload:m.payload,getData:fakeData})
 if m.calls.count()<>1 then throw "Apply did not issue exactly one catalog request"
 encoded=Enc(FormatJson([{id:"genre",values:["g0","g35"]}]))
 if instr(1,m.calls[0],"&values="+encoded)=0 or instr(1,m.calls[0],"addon_id=2")=0 then throw "array or exact catalog owner lost"
 browse("movie",24)
 if instr(1,m.calls[1],"skip=24")=0 or instr(1,m.calls[1],"&values="+encoded)=0 then throw "paging lost array"
 m.top.visible=true:m.draft=["g1"]
 choiceDismiss()
 if m.calls.count()<>2 or m.discoverVectors.genre[1]<>"g35" then throw "Cancel mutated query or fetched"
 m.top.visible=true:m.draft=[]:m.actions.itemSelected=1:choiceAction()
 if not m.top.visible or m.calls.count()<>2 then throw "empty required draft accepted"
 m.catalog={id:"",type:"movie",controls:[]}:m.discoverVectors={}
 browse("movie",0)
 if instr(1,m.calls[2],"catalog=")>0 then throw "catalog-less host received fabricated ID"
 print "DISCOVERY_CHOICES_RUNTIME_OK"
end sub
sub request(method,path,body,tag)
 m.calls.push(path)
end sub
sub rows(title,values,mode,description)
 m.mode=mode
end sub
sub cancelBrowse()
end sub
sub discoverBuildFilters()
end sub
sub uiRestoreFocus()
 m.restored=true
end sub
sub uiFocusChanged()
end sub
sub choiceDraftChanged()
end sub
sub uiEmpty(title,message)
end sub
function UiCatalogRequired(catalog,name)
 return false
end function
sub fakeFocus(active)
 m.focused=active
end sub
function fakeHasFocus()
 return m.focused
end function
function fakeFind(id)
 return m.nodes[id]
end function
function fakeData()
 return m.payload
end function
'''
with tempfile.TemporaryDirectory() as directory:
    script = Path(directory) / 'discovery.brs'
    script.write_text(source + '\n' + fixture)
    result = subprocess.run([*brs_command(), str(script), str(root/'source/Util.brs'),
        str(root/'source/DiscoveryControls.brs'), str(root/'source/ChoiceSelection.brs')],
        capture_output=True, text=True, timeout=30)
    print(result.stdout, result.stderr)
    assert result.returncode == 0 and 'DISCOVERY_CHOICES_RUNTIME_OK' in result.stdout
