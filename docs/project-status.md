[# Project status — watch-metrics

Posledná aktualizácia: 2026-07-23

## Čo je to

watchOS aplikácia LEN pre odvodené metriky (HRV status, RHR odchýlka, sleep score,
readiness, SpO2, dychová frekvencia). NEtrackuje aktivity — tie trackuje natívna
Workout app, my ich len čítame z HealthKitu. Solo dev, nulový rozpočet, agent-driven
vývoj cez Claude Code. Plné pozadie a architektonické rozhodnutia: pozri docs/ (ak tam plán je
uložený) alebo si vyžiadaj kompletný pôvodný plán znova.

## Kľúčové rozhodnutia (nemeň bez dobrého dôvodu)

- **Denné HRV okno, nie 3-dňové kĺzavé.** Reálne dáta z Health exportu (90 dní)
  ukázali medián 9 HRV vzoriek/noc, 92% nocí ≥5 vzoriek — lepšie než pôvodný
  konzervatívny predpoklad. M1/M2 (HRV status) sa počíta na dennej báze
  s 7d/28d baseline.
- VO2max dostupný len ~26% dní → nikdy nesmie blokovať readiness výpočet,
  traktuje sa ako "keď je k dispozícii".
- AppleSleepingWristTemperature chodí ako 1 vzorka/noc (Applov hotový priemer),
  neagregovať sám.
- HKHeartbeatSeries (RR intervaly pre RMSSD) NIE JE v Health exporte — treba
  overiť cez HKHeartbeatSeriesQuery priamo v appke neskôr (zatiaľ nespravené).
  Zatiaľ sa stavia len na SDNN.
- Sources/MetricsCore je čistý Swift Package: nesmie importovať HealthKit,
  CoreLocation ani SwiftUI. Testy pred implementáciou (TDD).

## Stav repozitára

- GitHub: https://github.com/joskoffel/watch-metrics (public — zostáva public
  kvôli zadarmo GitHub Actions macOS runnerom neskôr)
- `.gitignore` hotový
- `.claude/settings.json` hotový — deny pravidlá na ~/.ssh, ~/.aws, ~/.gnupg,
  .env, .pem, id_rsa, rm -rf, force push
- Sandbox v Claude Code zapnutý ("Sandbox BashTool, with auto-allow")
- `docs/data-availability-report.md` — reálna analýza z Health exportu, commitnuté
- `CLAUDE.md`, `Package.swift`, `Sources/MetricsCore/{SensorSample,Baseline}.swift`,
  `Tests/MetricsCoreTests/HRVStatusTests.swift` — vytvorené agentom, over že sú
  commitnuté (git status / git log)

## Čo ešte chýba (v poradí, ako na to)

1. ~~**Xcode.**~~ ✅ (2026-07-24) — Xcode.app stále nie je nainštalovaný (len
   Command Line Tools), a prvý pokus o `swift test` zlyhal presne na
   `no such module 'Testing'` (Testing.framework nedostupný pre SPM bez
   plného Xcode). Na opakovaný pokus to ale prešlo — CLT toolchain vie
   nájsť Testing.framework, len nekonzistentne (dôvod zatiaľ nejasný,
   možno cache/module-cache stav). Netreba teda čakať na Mac App Store
   Xcode inštaláciu, ale počítaj s tým, že `swift test` môže občas zlyhať
   na chýbajúcom module a treba ho pustiť znova.
2. ~~Po Xcode: `swift test --parallel`~~ ✅ (2026-07-24) — build OK, 1/1 test
   zlyhal ako očakávane: `hrvStatusComputesFromDailySamplesAgainstBaseline`
   — "HRVStatus not implemented yet — M1/M2 daily HRV status with 7d/28d
   baseline". Žiadne zakázané importy v Sources/MetricsCore (over grep).
3. ~~Implementovať fixture `Tests/Fixtures/night_sparse_hrv.json`~~ ✅
   (2026-07-24) — 5 vzoriek, hraničný prípad podľa data-availability-report.md,
   plus decode-verification test proti `SensorSample` (ISO8601 → Date).
4. ~~Implementovať RRArtifactFilter + RMSSD výpočet~~ ✅ (2026-07-24) —
   `RRInterval`, `RRArtifactFilter` (300–2000ms rozsah + 20% successive-change
   pravidlo), `RMSSD.calculate` (nil pre <2 intervaly). Otestované len proti
   syntetickým RR dátam — reálne RR intervaly stále čakajú na
   HKHeartbeatSeriesQuery overenie.
5. ~~BaselineTracker (7d/28d kĺzavé okná)~~ ✅ (2026-07-24) — `Baseline`
   (dátový typ, nahradil prázdny protokol) + `BaselineTracker` (výpočet),
   medián namiesto priemeru, confidence z pomeru dostupných/očakávaných dní
   v okne (≥0.85 high, ≥0.5 medium, inak low).
6. ~~HRVStatus (dnešná hodnota vs baseline + confidence skóre)~~ ✅
   (2026-07-24) — denný medián SDNN vs 7d/28d baseline (preferuje 28d,
   fallback na 7d), ±10% pásmo pre low/normal/high (poznačené ako heuristika
   na neskoršiu kalibráciu), confidence preberá z použitého baseline okna.
   Pôvodne červený test `hrvStatusComputesFromDailySamplesAgainstBaseline`
   je teraz zelený spolu s 4 ďalšími edge-case testami (žiadne vzorky, nízka
   confidence baseline, fallback na 7d, symetrický high prípad).
   **Týmto je celý M1/M2 blok hotový (kroky 3–6).**
7. Postupne ďalšie metriky: RHR odchýlka, sleep score, readiness kompozita.
   Ďalší krok (M3 RHR, alebo overenie HKHeartbeatSeriesQuery pre RR intervaly,
   alebo niečo iné) sa rozhodne spoločne s používateľom, nie automaticky.

## Nástroje a workflow

- Claude Code beží lokálne v termináli, v priečinku `watch-metrics`
- Remote Control (`/rc`) nastavený na ovládanie z telefónu — pokračuje v tej
  istej terminálovej session, ale vyžaduje bežiaci Mac (spadne pri hlbokom
  spánku, treba `/rc` znova po zobudení)
- Zvažuje sa Claude Code on the web (claude.ai/code) pre prácu bez nutnosti
  mať Mac zapnutý — vhodné najmä pokým sa pracuje na MetricsCore (nepotrebuje
  Xcode/simulátor). Pre Fázu 3+ (watchOS build) treba späť lokálny Mac.
- Token hygiena: `/clear` medzi neuzavretými úlohami, default model (Sonnet),
  Opus len na architektonické rozhodnutia, XcodeBuildMCP zatiaľ nepridané
  (nepotrebné kým nie je UI/watchOS target).

## Ako pokračovať v novom chate

Vlož tento súbor (alebo jeho obsah) do nového chatu so správou v štýle:
"Pokračujeme v projekte watch-metrics, toto je stav, poď ďalej odtiaľto."
]
