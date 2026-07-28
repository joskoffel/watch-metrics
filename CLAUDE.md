# watch-metrics

watchOS aplikácia pre **odvodené** zdravotné metriky: HRV status, RHR
odchýlka od baseline, sleep score, readiness, SpO2, dychová frekvencia.

## Scope

- Netrackujeme aktivity/tréningy. Tie trackuje natívna Workout app;
  my ich dáta z HealthKitu len čítame (napr. ako kontext pre readiness),
  nikdy nezapisujeme ani neduplicujeme jej funkcionalitu.
- Every metrika je odvodená z surových HealthKit vzoriek + baseline,
  nie priamy pass-through.

## Dátové reálie (viď `docs/data-availability-report.md`)

Report je zdroj pravdy pre frekvenciu/dostupnosť vzoriek. Kľúčové dôsledky
pre implementáciu:

- **HRV (M1/M2)**: medián 9 vzoriek/noc, 92% nocí ≥5 vzoriek. Počíta sa na
  **dennej báze** s **7d/28d baseline**. Nie 3-dňové kĺzavé okno — na to
  dáta nestačia konzistentne.
- **VO2max (M10)**: dostupné len ~26% dní. Traktuj ako voliteľný vstup
  ("keď je k dispozícii"), nikdy nie ako povinnú dennú metriku. Readiness
  výpočet sa **nikdy nesmie blokovať** na chýbajúcom VO2max.
- **AppleSleepingWristTemperature (M11)**: 1 vzorka/noc — je to už Applov
  hotový nočný priemer. Neagregujeme ju, berieme ako finálnu dennú hodnotu.
- **HKHeartbeatSeries / RR intervaly (RMSSD)**: nie sú v Health exporte,
  ale dostupnosť cez `HKHeartbeatSeriesQuery` je overená na reálnych
  hodinkách. Deväťnočný audit našiel RMSSD v 7/9 nocí (medián 4 série a
  142 RR intervalov/noc), preto RMSSD dopĺňa produkčný detail HRV. Existujúci
  **SDNN** status a recovery signal zostávajú autoritatívne a nezmenené.

## Sources/MetricsCore

Čistý Swift Package, bez závislosti na appke alebo OS zdravotných API:

- **ZAKÁZANÉ importy**: `HealthKit`, `CoreLocation`, `SwiftUI`.
- **ZAKÁZANÉ**: `Date()` (žiadny prístup na aktuálny čas), akékoľvek
  async I/O, akýkoľvek interný stav (žiadne `class` s mutable properties
  držiace dáta medzi volaniami).
- **Vstup**: pole vzoriek (`[SensorSample]`) + `Baseline`.
- **Výstup**: hodnota + confidence skóre.
- Dôsledok: všetky funkcie sú čisté a deterministické — rovnaký vstup,
  rovnaký výstup, testovateľné bez mockovania času alebo HealthKitu.

## Workflow

- Testy sa píšu **pred** implementáciou (TDD). Nová metrika/logika bez
  zlyhávajúceho testu najprv sa nepíše.
- Rýchly test loop: `swift test --parallel` — musí bežať pod 5s, žiadny
  Xcode build, žiadny simulátor. Toto je hlavný feedback loop počas vývoja
  MetricsCore.

## Formát priebežných reportov

Po KAŽDOM kroku (nie len na finálnom checkpointe) daj stručný report
namiesto plného výpisu nástrojov/príkazov/search výsledkov. Formát:

- Čo si urobil: 1-2 vety, len výsledok, nie proces (nie "Web Search(...),
  Fetch(...), Read 1 file" – to je šum, nie signál)
- Čo si zistil/rozhodol (ak relevantné): 1 veta, len ak to mení plán
  alebo je to niečo, čo musím vedieť (napr. "API sa volá inak, než sme
  predpokladali: X namiesto Y")
- Výsledok/stav: prešlo/zlyhalo, a ak zlyhalo, presne na čom
- Čo potrebuješ odo mňa (ak niečo): jedna jasná otázka/akcia

NEPOUŽÍVAJ: surové tool-call logy, "Ran N shell commands", search query
reťazce, plné cesty k dočasným súborom, timestampy nástrojov. Toto všetko
zostáva v internom behu, nie v reporte pre používateľa.

Príklad DOBRÉHO reportu:
"Overil som HealthKit API – správny názov je HKSeriesType.heartbeat(),
nie HKObjectType.heartbeatSeriesType() (pôvodne navrhnuté meno neexistuje).
Napísal som diagnostickú logiku (nový súbor HeartbeatSeriesDiagnostics.swift)
a UI (DiagnosticsView.swift). Build zlyhal na rovnakom signing probléme ako
minule – project.yml má Team ID, ale po xcodegen regenerácii treba znova
otvoriť Xcode GUI, aby sa provisioning profile znova rozpoznal.
Potrebujem: otvor Xcode, skontroluj Signing & Capabilities, potvrď že je
to čisté, a dám vedieť."

Toto pravidlo platí pre všetky budúce kroky v tomto projekte, nielen
pre tento.
