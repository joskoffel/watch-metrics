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
- **HKHeartbeatSeries / RR intervaly (RMSSD)**: nie sú v Health exporte.
  Dostupnosť treba overiť priamo cez `HKHeartbeatSeriesQuery` v appke
  (samostatná úloha, nie cez export). Kým sa neoverí, staviame len na
  **SDNN**, nie RMSSD.

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
