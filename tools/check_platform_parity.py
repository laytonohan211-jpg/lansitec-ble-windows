"""Run from project root before either platform release. Expected adapters are explicit."""
from pathlib import Path
import re,sys
android=Path('android-release/lib');windows=Path('github-windows/lib')
adapters={'blue_app.dart','modules/config/failed_device_page.dart','modules/config/updated_device_page.dart','modules/config/scan_device_page.dart','modules/home/connection_readiness.dart','modules/peripherals/peripheral_characteristic_detail_page.dart','modules/guided/guided_page.dart','modules/guided/livestock_setup_page.dart'}
def normalize(s):
 return re.sub(r'Ls BLE Guided 1\.\d+\.\d+','Ls BLE Guided VERSION',s).strip()
errors=[]
for p in android.rglob('*.dart'):
 rel=p.relative_to(android).as_posix();q=windows/rel
 if not q.exists():errors.append('MISSING Windows: '+rel)
 elif rel not in adapters and normalize(p.read_text(encoding='utf-8'))!=normalize(q.read_text(encoding='utf-8')):errors.append('UNREVIEWED DIFFERENCE: '+rel)
# Native Android decoder must have an identical Windows bundled counterpart.
a=Path('android-release/android/app/src/main/assets/decoders/livestock.js');w=Path('github-windows/assets/decoders/livestock.js')
if a.read_text(encoding='utf-8').strip()!=w.read_text(encoding='utf-8').strip():errors.append('Livestock decoder assets differ')
for e in errors:print(e)
print(f'{len(errors)} unreviewed differences; {len(adapters)} platform adapters require manual review.')
sys.exit(bool(errors))
