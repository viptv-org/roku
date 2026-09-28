"""Run the production error decoder without registry/network device emulation."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'components/ApiTask.brs').read_text()
def routine(name):
    start=source.index('function '+name+'(')
    return source[start:source.index('end function',start)+12]
production='\n'.join(routine(name) for name in ['ApiDisplayError','ApiErrorField','ApiSourceExpired'])
fixture='''
sub Main()
 expected="This IPTV provider has reached its connection limit. Stop another stream or choose another provider."
 if ApiDisplayError(FormatJson({error_code:"provider_connection_limit"}),429)<>expected then throw "coded limit lost"
 if ApiDisplayError(FormatJson({error:"Provider connection limit reached"}),429)<>expected then throw "legacy limit lost"
 if ApiDisplayError("",429)<>"Too many requests. Wait a moment and try again." then throw "rate limit confused"
 if ApiDisplayError(FormatJson({error:"Provider name is required"}),400)<>"Provider name is required" then throw "safe validation lost"
 for each body in [FormatJson({error:"https://provider.test/synthetic-private"}),FormatJson({error:"Cookie: synthetic-private"}),"bad JSON https://provider.test/synthetic-private"]
  if instr(1,ApiDisplayError(body,502),"synthetic-private")>0 then throw "private response leaked"
 end for
 if not ApiSourceExpired(FormatJson({error_code:"source_expired",error:"Refresh sources"})) then throw "coded expiry lost"
 if ApiSourceExpired(FormatJson({sourceExpired:true})) then throw "untrusted expiry flag accepted"
 print "API_ERROR_RUNTIME_OK"
end sub
'''
with tempfile.TemporaryDirectory() as directory:
    script=Path(directory)/'errors.brs';script.write_text(production+'\n'+fixture)
    result=subprocess.run([os.environ.get('VIPTV_BRS_CLI','brs'),str(script)],capture_output=True,text=True,timeout=30,cwd=directory)
    print(result.stdout);print(result.stderr)
    assert result.returncode==0 and 'API_ERROR_RUNTIME_OK' in result.stdout
    assert 'synthetic-private' not in result.stdout+result.stderr
