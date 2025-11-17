# mobidata_bw_flutter - Flutter client for MobiData BW
Ein plattformübergreifender Open-Data-Client für Mobilitätsdaten in Baden-Württemberg

Diese Flutter-App bietet einen schnellen, mobilen Zugriff auf die offenen Mobilitätsdaten der Plattform **MobiData BW**.  
Diese App entstand während des *Codevember-Hackathons 2025* und wird kontinuierlich erweitert.

Mehr zu MobiData BW: https://mobidata-bw.de/  
Mehr zum Hackathon: https://codevember.org/

## Haftungsausschluss
Dieses Projekt steht in keinem offiziellen Zusammenhang mit der NVBW – Nahverkehrsgesellschaft Baden-Württemberg mbH.
Es nutzt ausschließlich öffentliche, freilizenzierte Daten, die über die OpenData-Schnittstelle der Plattform MobiData BW bereitgestellt werden.
„MobiData BW“ ist eine Marke der NVBW mbH.

## Datenquellen und Lizenzen
Datenpaket: 
MobiData BW; NVBW – Nahverkehrsgesellschaft Baden-Württemberg mbH

Lizenz: 
Datenlizenz Deutschland – Namensnennung – Version 2.0 (DL-DE-BY 2.0)
https://www.govdata.de/dl-de/by-2-0

Weitere verwendete Lizenzen (z. B. Bibliotheken, Tile-Services, Icons) sind direkt im Impressum der App aufgelistet.

## Warum dieses Projekt?
Die Idee zur App entstand auf einem Digitalisierungs­kongress des Verkehrsministeriums Baden-Württemberg in Stuttgart. Dort wurde deutlich, wie umfassend und wertvoll die offenen Mobilitätsdaten von **MobiData BW** sind – gleichzeitig aber auch, dass es bislang keine mobile App gibt, die diese Daten gebündelt und nutzerfreundlich aufbereitet. Der Dienst existiert primär als Webseite, und vielen Menschen scheint gar nicht bewusst, dass diese Informationen überhaupt frei zugänglich sind (obwohl wahrscheinlich viele Apps die einzelnen Dienste nutzen).

Dieser Punkt wurde zu meinem Ausgangsmoment:  
*Wie kann man offene Daten so zugänglich machen, dass sie im Alltag wirklich genutzt werden?*

Diese Frage habe ich mit in den **jährlichen Codevember Hackathon** genommen, der 2025 erstmals gemeinsam mit dem **FZI Forschungszentrum Informatik in Karlsruhe** stattfand. Der Codevember e.V. bringt jedes Jahr kreative Menschen zusammen, um gemeinsam Ideen umzusetzen, voneinander zu lernen und neue Perspektiven auszuprobieren. Projekte entstehen dort im Game-Jam-Format: Jede Person kann eine Idee pitchen, alle Teilnehmenden stimmen in mehreren Runden ab, und anschließend formieren sich Teams rund um die favorisierten Themen.

Die MobiData-BW-App wurde gepitcht und innerhalb eines Wochenendes wurde ein funktionierender Prototyp entwickelt. Die offene und interdisziplinäre Stimmung des Hackathons half enorm: Entwickler*innen, Designer*innen und Interessierte aus verschiedenen Fachrichtungen diskutierten mit und teilten ihr Wissen und ihre Erfahrungen mit mir.

Was als Hackathon-Prototyp begann, hat sich über die Tage danach zu einer nahezu vollständigen, plattformübergreifenden App entwickelt – inklusive eigener Backend-Infrastruktur, Caching-Mechanismen, GTFS-Verarbeitung und kartographischen Funktionen. Das Projekt steht beispielhaft dafür, was entstehen kann, wenn OpenData, Neugier und ein unterstützendes Community-Umfeld aufeinandertreffen.


## Installation & Entwicklung

### Voraussetzungen

- Flutter (Version 3.3+ empfohlen)  
- Dart SDK (im Flutter-SDK enthalten)
- Android SDK (für mobile Builds)

### Projekt klonen

```bash
git clone https://github.com/p-schulz/mobidata-bw-flutter.git
cd mobidata-bw-flutter
flutter pub get
```

### App starten

Für Web-Browser
```bash
flutter run -d chrome
```

Für Android
```bash
flutter run -d android
```

Für iOS
```bash
flutter run -d ios
```



# Demo im Browser ausprobieren
Die App kann ohne Installation direkt im Browser ausprobiert werden:

**http://85.215.128.121/**

Hier laufen die Flutter-Web-Version sowie der zugehörige API-Server.

## Integrations Status

Die App befindet sich weiterhin in aktiver Entwicklung.
Aktuell integriert:
	•	ParkAPI (Belegungsstatus fehlt noch)
	•	Sharing-Angebot (Bike, Car, Scooter)
	•	Haltestellen (GTFS SQLite)
	•	Fahrradverleih
	•	Ladeinfrastruktur
	•	Suchfunktion per Geocoding (eigenes SQLite-Gazetteer)
	•	Live-Abfahrtsmonitor (TRIAS/alternative Echtzeitquellen)
	•	Verkehrsmeldungen

Geplant:
	•	Radnetz

### Backend-Projekt:
Die App benutzt eigene Hilfs-APIs. Der Servercode dazu liegt hier: https://github.com/p-schulz/mobidata-bw-flutter-backend

## Beiträge & Feedback

Beiträge, Bug-Reports oder Ideen sind jederzeit willkommen.
Bitte nutzt dafür die GitHub Issues oder Pull Requests.
