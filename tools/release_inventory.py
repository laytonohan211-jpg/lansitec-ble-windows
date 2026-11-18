"""Build-time inventory; no device data or signing keys are read."""
import json,re,hashlib,urllib.parse
from pathlib import Path
root=Path.cwd(); out=root/'dist';out.mkdir(exist_ok=True)
text=(root/'pubspec.lock').read_text(encoding='utf-8')
components=[]
for name,body in re.findall(r'^  ([\w]+):\n(.*?)(?=^  \w+:|^sdks:|\Z)',text,re.M|re.S):
 v=re.search(r'^    version: "([^"]+)"',body,re.M)
 if not v: continue
 item={'type':'library','name':name,'version':v.group(1),'purl':f'pkg:pub/{name}@{v.group(1)}'}
 sha=re.search(r'sha256: ["\']?([a-f0-9]{64})',body)
 if sha:item['hashes']=[{'alg':'SHA-256','content':sha.group(1)}]
 components.append(item)
(out/'SBOM.pub.cdx.json').write_text(json.dumps({'bomFormat':'CycloneDX','specVersion':'1.5','version':1,'metadata':{'properties':[{'name':'scope','value':'Pinned Dart packages; native dependencies and toolchains inventoried separately.'}]},'components':components},indent=2),encoding='utf-8')
config=root/'.dart_tool/package_config.json'
notices=['THIRD-PARTY NOTICES\nGenerated from resolved package source files. This is not a relicensing statement.']
missing=[]
for p in json.loads(config.read_text())['packages']:
 if p['name']=='flutter_blue':continue
 uri=urllib.parse.urljoin(config.as_uri(),p['rootUri'])
 parsed=urllib.parse.urlparse(uri)
 path=urllib.parse.unquote(parsed.path)
 if re.match(r'^/[A-Za-z]:',path):path=path[1:]
 folder=Path(path)
 files=[f for f in folder.iterdir() if f.is_file() and f.name.upper().startswith(('LICENSE','LICENCE','COPYING','NOTICE'))] if folder.exists() else []
 if not files:missing.append(p['name'])
 for f in sorted(files):notices.append(f'\n\n--- {p["name"]} / {f.name} ---\n'+f.read_text(encoding='utf-8',errors='replace'))
(out/'THIRD_PARTY_NOTICES.txt').write_text('\n'.join(notices),encoding='utf-8')
(out/'LICENSE_REVIEW.json').write_text(json.dumps({'packages_without_root_notice':missing,'manual_native_license_review_required':True},indent=2),encoding='utf-8')
files=[]
for folder in ['android','windows','assets/decoders']:
 for f in (root/folder).rglob('*'):
  if f.is_file() and 'build' not in f.parts and f.suffix in ['.gradle','.kts','.properties','.cmake','.txt','.js']:
   if f.name=='local.properties':continue
   files.append({'path':f.relative_to(root).as_posix(),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
(out/'NATIVE_SOURCE_INVENTORY.json').write_text(json.dumps(files,indent=2),encoding='utf-8')
print(f'Inventory: {len(components)} Dart components; {len(missing)} packages without root notices (review required).')
