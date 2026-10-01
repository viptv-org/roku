"""Exercise actual lazy catalog ownership, bounded concurrency and cursor termination."""
from brs_cli import brs_command
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'components/HomeCatalogScene.brs').read_text()
start=source.index('sub homeCatalogReplace(');end=source.index('end sub',start)+7
source=source[:start]+'''sub homeCatalogReplace(index as integer)
 m.replaced=index
end sub
'''+source[end:]
fixture='''
sub Main()
 m.mode="home":m.homeKeyValue="account|profile1":m.homePosition=[0,0]:m.homeExpanded=true
 m.homeCatalogs=invalid:m.homeData=[[],[],[],[],[],[],[]]:m.homeStates=[]:m.homeFailed=[]:m.homeDone={}
 m.homeRoot={appendChild:Append}:m.homeRowKeys=[0]:m.tasks=[]:m.queue=[]:m.sent=[]
 catalogs=[]
 for i=0 to 99
  catalogs.push({id:"catalog"+i.toStr(),addon_id:"addon",addon_name:"Addon",name:"Shelf "+i.toStr(),type:"movie",extra:[]})
 end for
 homeUseCatalogs({ok:true,data:catalogs})
 if m.homeCatalogs.count()<>100 or m.homeRowKeys.count()<>101 then throw "catalog inventory truncated"
 if m.sent.count()<>1 then throw "cold Home swept hidden catalog shelves"
 if instr(1,m.sent[0].path,"catalog=catalog0")=0 then throw "first catalog identity lost"
 m.homeExpanded=false:m.homePosition=[27,0]
 homeCatalogPump(true)
 if m.homeCatalogPending.count()>2 then throw "more than two catalog requests"
 firstTag=m.sent[m.sent.count()-2].tag
 secondTag=m.sent[m.sent.count()-1].tag
 homeCatalogResponse(firstTag,{ok:true,data:{metas:[{id:"film1",name:"Film"}],has_more:true,next_skip:100}})
 homeCatalogResponse(secondTag,{ok:true,data:{metas:[{id:"film2",name:"Film 2"}],has_more:false}})
 if m.homeCatalogPending.count()>2 then throw "response exceeded concurrency"
 ' Follow-up page repeats the first ID: stop despite upstream has_more.
 tag="homecatalog:repeat":m.homeCatalogPending[tag]={index:27,skip:100,scope:m.homeKeyValue}
 homeCatalogResponse(tag,{ok:true,data:{metas:[{id:"film1",name:"Film"}],has_more:true,next_skip:200}})
 if m.homeCatalogs[20].nextSkip<>invalid or m.homeData[27].count()<>1 then throw "repeated page loops or duplicates"
 ' Navigating far away evicts the old payload and cancels its queued owners.
 m.homePosition=[57,0]:homeCatalogPump(true)
 if m.homeCatalogs[20].loaded or m.homeData[27][0].action<>"homecatalogload" then throw "distant catalog payload retained"
 if m.homeCatalogPending.count()>2 then throw "rapid movement expanded concurrency"
 ' A cancelled completion cannot replace the new window.
 replaced=m.replaced
 homeCatalogResponse(firstTag,{ok:true,data:{metas:[{id:"stale"}]}})
 if m.replaced<>replaced then throw "cancelled catalog mutated view"
 ' Failed rows do not automatically retry forever.
 tag=m.sent[m.sent.count()-1].tag:index=m.homeCatalogPending[tag].index
 homeCatalogResponse(tag,{ok:false})
 if not m.homeCatalogs[index-7].failed or m.homeData[index][0].action<>"homecatalogretry" then throw "missing actionable failed shelf"
 print "HOME_CATALOG_RUNTIME_OK"
end sub
sub Append(node as object)
end sub
function homeRow(index as integer) as object
 return {}
end function
function HomeShelfRank(index as integer) as integer
 return index
end function
sub homeHero()
end sub
sub request(method as string,path as string,body as dynamic,tag as string)
 m.sent.push({path:path,tag:tag})
 m.queue.push({path:path,tag:tag+"|1"})
end sub
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'catalog.brs';p.write_text(source+'\n'+fixture)
 r=subprocess.run([*brs_command(),str(p),str(root/'source/Util.brs'),str(root/'source/BrowsePolicy.brs')],capture_output=True,text=True,timeout=40)
 print(r.stdout,r.stderr)
 assert r.returncode==0 and 'HOME_CATALOG_RUNTIME_OK' in r.stdout
