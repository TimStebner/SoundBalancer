# SoundBalancer 🎧

**SoundBalancer** ist eine native, moderne macOS Statusleisten-Applikation (Menu Bar Extra) in Swift & SwiftUI mit **Liquid Glass**-Design. Sie ermöglicht die individuelle Lautstärkeregelung für alle laufenden Programme und die getrennte Auswahl von Ein- und Ausgabegeräten – **völlig ohne virtuelle Audiotreiber oder Kernel-Erweiterungen**, basierend auf Apples nativer **Core Audio Process-Tap API** (macOS 14.2+).

---

## 🚀 Gelöste Probleme & Features

### 1. Per-App Lautstärkemixer (0% bis 400% Gain Boost, +12 dB)
* **WhatsApp vs. YouTube Problem behoben**: WhatsApp-Sprachnachrichten und Anrufe sind oft drastisch lauter als Webvideos oder Musik. In SoundBalancer kann jedes Programm einzeln geregelt werden (z. B. WhatsApp dämpfen oder YouTube/Safari auf bis zu 400% boosten).
* **Call Passthrough & Voice-Kompensation**: Apps, die gerade das Mikrofon verwenden, werden standardmäßig direkt durch macOS geroutet, damit der Process Tap die Echo-Unterdrückung bei Anrufen nicht stört. Gespeicherte Lautstärke- und Mute-Werte greifen nach dem Call wieder; das Verhalten ist abschaltbar. Außerhalb eines Calls werden Kommunikations-Apps weiterhin mixdown-kompensiert (+6 dB).
* **Native App-Umleitung**: Einzelne Apps lassen sich direkt über macOS routen, wenn ein Bluetooth-Gerät oder die App selbst mit Process Taps Probleme verursacht. Für diese App sind Lautstärke und Mute in SoundBalancer währenddessen nicht aktiv.
* **Hyperbolic Soft Limiter (`tanh`)**: Verhindert digitales Clipping bei extremen Boost-Pegeln über 100% und garantiert sauberen Klang ohne Verzerrungen.
* **Echte App-Erkennung**: Erkennt laufende Audio-Apps automatisch und löst Browser-/Electron-Hilfsprozesse (z. B. WhatsApp Helper, Chrome Helper) auf die echte App mit Name und App-Icon auf.
* **Mute & Reset**: Schnelles Stummschalten oder Zurücksetzen auf 100% mit einem Klick.

### 2. Schnelle Ein- und Ausgabegeräte-Auswahl (AirPods Telefonie-Fix)
* **Telefonate ohne Qualitätsverlust**: Wenn AirPods verbunden sind, schaltet macOS bei Telefonaten (WhatsApp, Teams, FaceTime) oft automatisch auch das Mikrofon auf die AirPods, was sie in den minderwertigen 16 kHz Bluetooth-Handsfree-Codec zwingt.
* **Die Lösung**: In SoundBalancer wählst du direkt im Menü **Ausgabe: AirPods** und **Eingabe: MacBook Air Mikrofon**. Dadurch bleiben deine AirPods im glasklaren Stereo-AAC-Modus (44.1/48 kHz) und die Stimme wird über das MacBook-Mikrofon übertragen.

### 3. Loudness-Kompensation für AirPods & Mehrkanal
* **Schluss mit zu leisen AirPods**: Verhindert die automatische Core-Audio-Dämpfung bei Aggregate-Devices auf AirPods und Mehrkanal-Geräten durch dynamische Kanal-Kompensation.

### 4. Liquid Glass Design & Zero-Footprint
* Natives SwiftUI mit macOS `.ultraThinMaterial`, Glassmorphism-Karten, dezenten Lichtkanten und animierten Reglern.
* **Zero-Footprint**: Sobald du SoundBalancer schließt (`Cmd+Q` oder Power-Icon), werden alle Taps sofort beendet und der Ton läuft wieder direkt über den macOS-Standardpfad. Keine Hintergrund-Daemons oder Reste im System.

---

## 🛠️ Build & Installation

### Kompilieren & App-Bundle erstellen:
```bash
make app
```
Das fertige, signierte Programm liegt danach unter `build/SoundBalancer.app`.

### Starten:
```bash
open build/SoundBalancer.app
```
*Hinweis*: Beim ersten Start bittet macOS um die Berechtigung **System Audio Recording** (unter *Systemeinstellungen > Datenschutz & Sicherheit > Bildschirm- & Systemaudioaufnahme*), damit Core Audio die Audio-Streams für den Mixer abgreifen darf.

### Nach `/Applications` kopieren (optional):
```bash
cp -R build/SoundBalancer.app /Applications/
```
