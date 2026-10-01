"""Artwork targets graphics pixels while Poster decode dimensions stay logical."""
from brs_cli import brs_command
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'source/ImagePolicy.brs').read_text()
source=source[:source.index('function ImageUrl')].replace('CreateObject("roDeviceInfo")','FakeDevice()')
fixture='''
sub Main()
 m.imageScale=invalid
 if ImagePixels(213)<>320 or ImagePixels(120)<>180 then throw "FHD artwork undersampled"
 print "IMAGE_GRAPHICS_SCALE_OK"
end sub
function FakeDevice() as object
 return {getUIResolution:Resolution}
end function
function Resolution() as object
 return {width:1920,height:1080}
end function
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'image-resolution.brs';p.write_text(source+fixture)
 result=subprocess.run([*brs_command(),str(p)],capture_output=True,text=True,timeout=30)
 print(result.stdout,result.stderr)
 assert result.returncode==0 and 'IMAGE_GRAPHICS_SCALE_OK' in result.stdout
