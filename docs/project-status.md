[# Project status — watch-metrics

Posledná aktualizácia: 2026-07-25

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
- **Gate G0.2 overené (2026-07-24): HKHeartbeatSeriesQuery reálne funguje.**
  HKHeartbeatSeries (RR intervaly) nie je v Health exporte, ale priamo cez
  HealthKit na zariadení áno — overené diagnostickou appkou
  (`HealthKitDiagnostics/`, samostatný watchOS target mimo SwiftPM balíka):
  **71 series za posledných 7 dní, prvá séria obsahuje 24 RR intervalov.**
  RRArtifactFilter + RMSSD (krok 4) sa teda dajú napojiť na reálne dáta,
  nie len syntetické — RMSSD už nie je natrvalo blokované na SDNN.
  `HealthKitDiagnostics` zostáva čisto diagnostický nástroj (Gate G0.2),
  nie súčasť produkčnej appky — jeho HealthKit query logika sa musí
  neskôr prepísať/presunúť do reálnej watch-metrics appky ako HealthKit
  integračná vrstva (samostatný budúci krok, mimo Sources/MetricsCore,
  keďže MetricsCore nesmie importovať HealthKit).
- Sources/MetricsCore je čistý Swift Package: nesmie importovať HealthKit,
  CoreLocation ani SwiftUI. Testy pred implementáciou (TDD).
- **SpO2 (M14) používa absolútne klinické hranice, nie baseline-relatívny
  vzor ako HRV (±10%) a RHR (±5%).** SpO2 má populačne platnú klinickú
  hranicu (≥95% normal, 90-94.9% low, <90% critical — klinický konsenzus,
  nie heuristika na kalibráciu), takže osobný baseline nie je potrebný na
  to, aby bol level zmysluplný. Preto aj `SpO2Status.compute` vracia nil
  LEN keď chýbajú dnešné vzorky — chýbajúci baseline (7d aj 28d) level
  nepotláča, len zníži confidence na `.low`. `SpO2Status.confidence`
  NEOVPLYVŇUJE dôveryhodnosť `level` — budúca readiness/composite logika
  to nesmie použiť na potláčanie `.critical`/`.low` SpO2 hodnôt.

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
7. ~~Overenie HKHeartbeatSeriesQuery (Gate G0.2)~~ ✅ (2026-07-24) —
   `HealthKitDiagnostics/` (samostatný watchOS Xcode target, xcodegen,
   mimo Sources/MetricsCore) nainštalovaný a spustený na reálnych
   hodinkách. Výsledok: **71 series/7 dní, 24 RR intervalov v prvej
   sérii.** Real RR dáta sú dostupné — RMSSD pipeline z kroku 4 sa dá
   napojiť na reálne dáta, nie len syntetické (viď aj Kľúčové rozhodnutia
   vyššie). HealthKitDiagnostics zostáva diagnostický nástroj; presun
   jeho query logiky do produkčnej appky je samostatný budúci krok.
8. ~~M3 — RHR odchýlka od baseline~~ ✅ (2026-07-25) — `RHRStatus`, rovnaký
   tvar ako HRVStatus (denný medián RestingHeartRate vs 7d/28d baseline,
   28d preferované, fallback na 7d), ale s vlastným `RHRStatusLevel`
   (`elevated`/`normal`/`suppressed` namiesto `low`/`high` — smer "zlé" je
   opačný než pri HRV, vyššia RHR je varovný signál) a užším ±5% pásmom
   (RHR je deň-na-deň stabilnejšia než HRV, širšie pásmo by utlmilo signál).
   5 testov (normal, žiadne vzorky, nízka confidence, fallback+suppressed,
   elevated) — všetky zelené spolu s predošlými 20.
9. ~~Ranný end-to-end HRV test na reálnom zariadení~~ ✅ (2026-07-25) — po
   nočnom spánku appka (HealthKitDiagnostics/HRVStatusView) ukázala
   **60.6 ms, level normal, confidence low** na Apple Watch Ultra 3.
   Potvrdzuje to, že celý pipeline HealthKit → HRVIntegration →
   MetricsCore (BaselineTracker + HRVStatus) → UI funguje end-to-end na
   reálnom zariadení, vrátane confidence signálu pre riedke ranné dáta —
   nízka confidence pri malom počte nočných vzoriek je očakávané správanie
   BaselineTracker, nie bug.
10. ~~SpO2 (M14)~~ ✅ (2026-07-25) — `SpO2Status` v MetricsCore: level z
    **absolútnych klinických hraníc** (≥95% normal, 90–94.9% low, <90%
    critical), NIE relatívne k baseline (na rozdiel od HRV/RHR — SpO2 má
    populačne platnú klinickú hranicu, HRV/RHR nemá). Zámerne sa odchyľuje
    od HRV/RHR nil-handling vzoru: vracia nil LEN keď chýbajú dnešné SpO2
    vzorky, chýbajúci baseline confidence len zníži na `.low`, level sa
    počíta vždy. `confidence` tu neovplyvňuje dôveryhodnosť `level`
    klasifikácie (doc-comment v kóde) — budúca readiness logika to nesmie
    použiť na potláčanie `.critical`/`.low`. 10 testov (8 pôvodných +
    2 symetrické boundary: 94.9%→low, 89.9%→critical), všetky zelené
    spolu s predošlými 25 (35 spolu). V `HealthKitDiagnostics/`:
    `SpO2Integration.swift` (rovnaký vzor ako HRVIntegration, pozor na
    `HKUnit.percent()` vracajúci zlomok 0.0–1.0, nie 0–100 — treba ×100),
    `SpO2StatusView.swift`, a nový `MetricsOverviewView.swift` zobrazujúci
    HRV aj SpO2 spolu s farebným indikátorom (zelená/žltá/červená) ako
    hlavná obrazovka appky.
11. Postupne ďalšie metriky: sleep score, readiness kompozita,
    a napojenie RMSSD na reálne RR dáta cez HealthKit integračnú vrstvu.
    Ďalší krok sa rozhodne spoločne s používateľom, nie automaticky.

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

## Known issues

- **xcodebuild CLI signing po xcodegen generate (2026-07-25).** Known issue
  (nie definitívne overený limit): xcodebuild spustený z CLI/agent kontextu
  opakovane zlyhával na "No Account for Team" hneď po xcodegen generate, aj
  keď DevelopmentTeam bol správne v project.pbxproj. Pridanie attributes:
  bloku do project.yml problém nevyriešilo pri jednom teste, ale pri
  revertovaní sa ukázalo, že TargetAttributes v pbxproj si DevelopmentTeam
  hodnotu drží/cachuje naprieč regeneráciami neočakávane – čo spochybňuje,
  že ide o čistý, reprodukovateľný limit. Nie je isté, či ide o timing
  (Xcode GUI proces bežiaci na pozadí verzus CLI), cache, alebo niečo iné.

  Overený, spoľahlivý postup zatiaľ: ak CLI build zlyhá na "No Account for
  Team", otvor Xcode GUI → Signing & Capabilities → ručne vyber Team z
  dropdownu → počkaj na čistý stav → skús CLI build znova. Toto vždy
  zafungovalo doteraz (4x), aj keď presný mechanizmus prečo nie je jasný.

  Ak sa niekedy v budúcnosti bude toto skúmať hlbšie, začni tým, že over
  TargetAttributes v pbxproj PRED a PO xcodegen generate (nie len po), aby
  bolo jasné, čo presne sa mení/nemení pri regenerácii.

## Ako pokračovať v novom chate

Vlož tento súbor (alebo jeho obsah) do nového chatu so správou v štýle:
"Pokračujeme v projekte watch-metrics, toto je stav, poď ďalej odtiaľto."
]
