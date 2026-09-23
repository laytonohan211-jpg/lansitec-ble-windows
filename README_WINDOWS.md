# Ls BLE Guided — Windows desktop preview

Port separato dei sorgenti 1.3.3 + avviso di lettura parametri. Questo archivio contiene i sorgenti completi: **non contiene un eseguibile Windows compilato o collaudato**.

## Generare l'app sul PC

1. Usa Windows 10/11 x64 con Bluetooth Low Energy, Flutter **3.29.0** nel PATH e Visual Studio 2022 con **Desktop development with C++** e Windows SDK. Abilita Developer Mode in Windows per i collegamenti dei plugin Flutter.
2. Estrai il progetto in una cartella locale. Apri PowerShell in quella cartella e avvia `./build_windows.ps1`, oppure apri `BUILD_WINDOWS.cmd`.
3. La procedura verifica il codice, esegue i test e crea `dist/Ls_BLE_Guided_Windows_x64.zip`. Per distribuire l'app, usa l'intero ZIP: estrailo e apri `Ls_BLE_Guided.exe`. Le DLL e la cartella `data` devono rimanere accanto all'EXE. Il PC di destinazione può richiedere Microsoft Visual C++ Redistributable x64.

In alternativa è incluso un workflow GitHub Actions manuale `Build Windows desktop`, che genera lo stesso ZIP su Windows. Non è stato pubblicato né avviato automaticamente.

## Uso

Attiva il Bluetooth del PC, apri l'app e scegli il dispositivo. Se il beacon richiede un PIN, associalo prima da **Impostazioni Windows → Bluetooth e dispositivi → Aggiungi dispositivo**. Non è richiesto il GPS del PC.

La lettura iniziale dei parametri e il messaggio «Reading device settings. Please wait a few seconds…» rimangono attivi. I successivi aggiornamenti si richiedono con Refresh, senza polling periodico. Le conferme e le decodifiche dei valori usano la logica già presente nella versione mobile.

## Adattamenti

- Backend BLE Windows `flutter_blue_plus_winrt 0.0.18`, compatibile con l'interfaccia 8.0.1 del progetto; dipendenze bloccate.
- Impostazioni Bluetooth di Windows; nessuna richiesta di permessi Android/iPhone sul PC.
- Esportazione CSV nella cartella Download del PC.
- Decoder uplink offline con gli stessi script Lansitec, eseguiti tramite QuickJS (`flutter_js 0.8.7`).
- Finestra desktop e conferma prima della chiusura/disconnessione.
- Batch Config: i dispositivi protetti vanno associati in Windows prima del batch; non viene usato il pairing automatico Android.

## Verifica richiesta su Windows

Questa consegna non certifica la compilazione C++ né il funzionamento con un adattatore BLE reale. Prima di distribuirla, compilare e verificare: scansione, connessione, lettura iniziale tracker/beacon, modifica con conferma/readback, Refresh, reboot, disconnessione, decoder offline ed esportazione CSV. Verificare anche il pairing di un beacon protetto e un batch prima di usarli su più dispositivi.

Il vecchio BUILD_RECEIPT e i log Android inclusi nel progetto documentano esclusivamente la build mobile precedente. Non attestano una build Windows. Le licenze originali e dei plugin rimangono applicabili.

Riferimenti: https://docs.flutter.dev/platform-integration/windows/setup e https://pub.dev/packages/flutter_blue_plus_winrt/versions/0.0.18
