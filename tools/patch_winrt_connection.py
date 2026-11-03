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

# Undo the 1.5.4 retention experiment, including restored build caches.
retention_changes=[('auto gatt_result = co_await device.GetGattServicesAsync(BluetoothCacheMode::Uncached);', 'auto gatt_result = co_await device.GetGattServicesAsync(BluetoothCacheMode::Uncached);\n            // Lansitec: retain a GATT session for the selected device.\n            auto session = co_await GattSession::FromDeviceIdAsync(device.BluetoothDeviceId());'), ('// Only send connection state if not already sent by OnConnectionStatusChanged', '// All cancellation/ownership checks above run on the UI thread.\n                 // Do not enable retention for a cancelled connection.\n                 if (session && session.CanMaintainConnection()) {\n                     session.MaintainConnection(true);\n                     gatt_sessions_[remote_id] = session;\n                     Log("MaintainConnection enabled for %s", remote_id.c_str());\n                 } else {\n                     Log("MaintainConnection unavailable for %s", remote_id.c_str());\n                 }\n                 // Only send connection state if not already sent by OnConnectionStatusChanged'), ('            session.Close();', '            session.MaintainConnection(false);\n            session.Close();')]
for original,patched in retention_changes:
 s=s.replace(patched,original)
start=s.index('winrt::fire_and_forget FlutterBluePlusWinrtPlugin::WriteCharacteristicAsync(')
end=s.index('winrt::fire_and_forget FlutterBluePlusWinrtPlugin::ReadDescriptorAsync(',start)
section=s[start:end]
old_catch='} catch (const std::exception& e) { error_msg = e.what(); }'
new_catch='} catch (const winrt::hresult_error& e) { error_msg = "WinRT HRESULT " + std::to_string(static_cast<int32_t>(e.code())) + ": " + winrt::to_string(e.message()); } catch (const std::exception& e) { error_msg = e.what(); }'
if 'WinRT HRESULT' not in section:
 if section.count(old_catch)!=1:raise RuntimeError('Unexpected write error handler')
 section=section.replace(old_catch,new_catch)
s=s[:start]+section+s[end:]
if 'MaintainConnection(true)' in s:raise RuntimeError('Retention rollback incomplete')
p.write_text(s,encoding='utf-8')
print('WinRT retention disabled; original HRESULT diagnostics enabled')
