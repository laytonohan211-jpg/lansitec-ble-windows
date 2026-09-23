# Ls BLE Guided — Windows

[Scarica il programma di installazione EXE](https://github.com/laytonohan211-jpg/lansitec-ble-windows/releases/latest/download/Ls_BLE_Guided_Windows_Setup.exe)

Scarica e apri `Ls_BLE_Guided_Windows_Setup.exe`, completa l'installazione e avvia Ls BLE Guided dal desktop. Windows 10/11 x64, Bluetooth attivo. Per dispositivi protetti da PIN, esegui prima l'associazione dalle Impostazioni Bluetooth di Windows.

Il pacchetto comprende le librerie runtime. L'installer non è firmato digitalmente. Il funzionamento BLE va verificato con l'adattatore e i dispositivi reali.

## Build

Flutter 3.29.0 e Visual Studio 2022 C++. Il workflow GitHub Actions verifica il codice, esegue i test, compila Windows, crea l'installer, verifica avvio e installazione e pubblica una release. Il codice proviene dal port Windows fornito dall'utente; logica del protocollo conservata.
