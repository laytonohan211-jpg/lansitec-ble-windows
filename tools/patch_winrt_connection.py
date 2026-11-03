"""Patch the locked WinRT 0.0.18 dependency; fail if upstream source changes."""
from pathlib import Path
import json, hashlib
from urllib.parse import urljoin, urlparse, unquote
config=Path('.dart_tool/package_config.json').resolve()
package=next(p for p in json.loads(config.read_text())['packages'] if p['name']=='flutter_blue_plus_winrt')
uri=urljoin(config.as_uri(),package['rootUri'])
root=Path(unquote(urlparse(uri).path).lstrip('/') if __import__('os').name=='nt' else unquote(urlparse(uri).path))
p=root/'windows/flutter_blue_plus_winrt_plugin.cpp'
s=p.read_text(encoding='utf-8')
marker='// Lansitec: retain a GATT session for the selected device.'
if marker in s:
 print('WinRT connection retention patch already installed')
 raise SystemExit(0)
if 'version: 0.0.18' not in (root/'pubspec.yaml').read_text():raise RuntimeError('Unexpected WinRT version')
changes=[(
 'auto gatt_result = co_await device.GetGattServicesAsync(BluetoothCacheMode::Uncached);',
 '''auto gatt_result = co_await device.GetGattServicesAsync(BluetoothCacheMode::Uncached);
            // Lansitec: retain a GATT session for the selected device.
            auto session = co_await GattSession::FromDeviceIdAsync(device.BluetoothDeviceId());'''),(
 '// Only send connection state if not already sent by OnConnectionStatusChanged',
 '''// All cancellation/ownership checks above run on the UI thread.
                 // Do not enable retention for a cancelled connection.
                 if (session && session.CanMaintainConnection()) {
                     session.MaintainConnection(true);
                     gatt_sessions_[remote_id] = session;
                     Log("MaintainConnection enabled for %s", remote_id.c_str());
                 } else {
                     Log("MaintainConnection unavailable for %s", remote_id.c_str());
                 }
                 // Only send connection state if not already sent by OnConnectionStatusChanged'''),(
 '            session.Close();',
 '''            session.MaintainConnection(false);
            session.Close();''')]
for old,new in changes:
 if s.count(old)!=1:raise RuntimeError('Unexpected patch context: '+old)
 s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
print('Applied WinRT session retention and explicit release patch')
