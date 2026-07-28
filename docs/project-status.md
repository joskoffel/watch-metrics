[# Project status — watch-metrics

Posledná aktualizácia: 2026-07-28

## Čo je to

Watch Metrics je watch-only produktová aplikácia pre osobný denný prehľad
odvodených metrík zo HealthKitu. Aktivity netrackuje — tie zaznamenáva natívna
Workout app a Watch Metrics číta iba existujúce údaje. Aktuálny produktový shell
obsahuje Today, detaily metrík, 14-dňovú históriu a Settings. Debug build navyše
obsahuje oddelené Developer menu. Produktové smerovanie je **morning-first
HRV/recovery**; cieľom nie je kopírovať Apple Vitals. Aplikácia nie je
zdravotnícka pomôcka.

## Kľúčové rozhodnutia (nemeň bez dobrého dôvodu)

- **Nočné HRV okno podľa hlavného spánku, nie kalendárny deň ani 3-dňové
  kĺzavé okno.** Reálne dáta z Health exportu (90 dní)
  ukázali medián 9 HRV vzoriek/noc, 92% nocí ≥5 vzoriek — lepšie než pôvodný
  konzervatívny predpoklad. M1/M2 (HRV status) sa počíta na dennej báze
  s 7d/28d baseline.
- VO2max dostupný len ~26% dní → nikdy nesmie blokovať readiness výpočet,
  traktuje sa ako "keď je k dispozícii".
- AppleSleepingWristTemperature chodí ako 1 vzorka/noc (Applov hotový priemer),
  neagregovať sám.
- **Gate G0.2 overené (2026-07-24): HKHeartbeatSeriesQuery reálne funguje.**
  HKHeartbeatSeries (RR intervaly) nie je v Health exporte, ale priamo cez
  HealthKit na zariadení áno — pôvodne overené diagnostickým režimom dnešnej
  Watch Metrics appky (projekt je historicky uložený v priečinku
  `HealthKitDiagnostics/`):
  **71 series za posledných 7 dní, prvá séria obsahuje 24 RR intervalov.**
  RRArtifactFilter + RMSSD (krok 4) sa teda dajú napojiť na reálne dáta,
  nie len syntetické — RMSSD už nie je natrvalo blokované na SDNN.
  Surový heartbeat-series nástroj zostáva dostupný iba cez Settings →
  Developer; produkčný target a scheme sa volajú `WatchMetrics`.
- Sources/MetricsCore je čistý Swift Package: nesmie importovať HealthKit,
  CoreLocation ani SwiftUI. Testy pred implementáciou (TDD).
- Každá recovery noc má jednu app-layer reprezentáciu `ResolvedNight`: hranice
  sú `mainSleep.start...end` a deň je lokálne ráno podľa `sleep.end`. SDNN,
  SpO₂, heartbeat series a validačný nočný pulz používajú presne tento interval.
  Ak hlavný spánok chýba, nočné okno sa nevymýšľa. Historická baseline používa
  iba skoršie noci — cieľová noc ani budúce dáta do nej nevstupujú.
- **Ranný brief používa skutočný čas spánku, nie iba hranice session.**
  `SleepSession.asleepDuration` je súčet unikátneho času asleep segmentov
  bez awake/inBed medzier a bez dvojitého započítania overlapov; podľa tejto
  hodnoty sa vyberá hlavný spánok aj zobrazuje dĺžka. Doručenie je povolené
  najneskôr presne o 10:00, scheduled beh autoritatívne deduplikuje podľa
  `mainSleep.end` a scheduling reaguje na výsledok celého pokusu vrátane
  zlyhania notifikácie, nie iba na čisté `BriefDecision`.
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

## Produkčná Watch Metrics appka

- Projekt, app target a scheme: `WatchMetrics`; display name **Watch Metrics**,
  bundle ID `com.watchmetrics.WatchMetrics`.
- Watch-only konfigurácia, HealthKit entitlement, signing team `XXRA2Z8LT5`
  a ranné background scheduling/deduplikácia zostali zachované.
- `DailyOverviewStore` je jediný `@MainActor @Observable` koordinátor denného
  prehľadu. SwiftUI views neobsahujú HealthKit query logiku a jedna chýbajúca
  metrika neblokuje ostatné.
- Reálne napojené dáta: hlavný spánok so `asleepDuration`, nočné HRV SDNN,
  denný Apple Health resting heart rate a nočné SpO₂. HRV/RHR/SpO₂ poskytujú
  kompaktný 14-dňový trend. RHR sa zámerne neoznačuje ako nočné meranie.
- Today je tmavý recovery-first dashboard: kvalitatívny `RecoverySignal` tvorí
  hero s jedným pomalým dekoratívnym pulzom a štyri metriky sú v kompaktnom
  2×2 gride. Reduce Motion pulz vypne a historické dni používajú statický hero.
  Ranný brief je kompaktný footer; History otvára rovnaký reference-date-aware
  dashboard. Verejné Settings obsahuje stav notifikácií, HealthKit informáciu
  a About; bezpečný test a Developer nástroje sú dostupné iba v Debug builde.
- Release 1.0 má angličtinu ako development language a úplnú slovenskú
  lokalizáciu cez String Catalogs vrátane notifikácií, komplikácie a
  HealthKit usage description. App a komplikácia majú synchronizované verzie
  1.0 (build 2), privacy manifesty a reprodukovateľnú archive konfiguráciu
  z `project.yml`.
- Today aj detaily používajú stabilné identity farby nezávislé od levelu:
  sleep violet, HRV cyan, RHR magenta a SpO₂ blue. Detail má spoločný hero,
  tematické obsahové/trend panely a samostatnú textovú status kapsulu so
  semantickou farbou; level nikdy nepremaľuje identitu metriky. Grafy kreslia
  iba platné historické body bez smoothingu alebo interpolovania chýbajúcich
  dát.
- Diagnostics, heartbeat series a `BriefDebugPanel` sú iba v Developer menu.
  Developer menu navyše obsahuje **HRV Data Audit** pre posledných 28
  vyriešených nocí. Audit lokálne porovnáva nočný SDNN s RMSSD, reportuje
  počet heartbeat sérií, raw/prijaté RR intervaly, artifact-filter ratio,
  mediány pokrytia a riedke/chybné noci. Zároveň validačne počíta počet,
  medián, robustnú dolnú hodnotu a pokrytie tretín nočného heart rate.
  Nič neposiela mimo zariadenia a osobné hodnoty nie sú súčasťou repozitára.
  SwiftUI sample modely pokrývajú recovery stavy, čiastočné/loading dáta,
  malé/Ultra rozmery, statický historický Today, detail, History aj error stav
  a nepoužívajú sa v produkčnom HealthKit behu.
- `WatchMetricsWidgetExtension` ostáva statická bez App Group a live HealthKit
  zdieľania. Tap otvorí hostiteľskú aplikáciu.
- Autoritatívny používateľský HRV status a `RecoverySignal` zostávajú pôvodné
  SDNN výsledky. Produkčný detail **Nočná HRV** ich dopĺňa o RR-derived RMSSD,
  jeho vlastnú 7/28-dňovú osobnú baseline a kvalitatívnu zhodu signálov.
  RMSSD je voliteľné: chýbajúca noc, baseline alebo oprávnenie nepotlačí SDNN
  ani ranný brief. Nočný heart-rate settling zostáva iba auditný výstup.
- Budúce chunky: historický sleep chart, live metric complication, readiness,
  respiratory rate a VO₂max. Generický sleep/readiness score sa neplánuje.

## Čo ešte chýba (v poradí, ako na to)

1. ~~**Xcode.**~~ ✅ — plný Xcode je nainštalovaný; watchOS simulator buildy
   a xcodegen projekt sú dostupné lokálne.
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
   vyššie). Surový diagnostický nástroj dnes zostáva v Developer menu.
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
    pôvodné diagnostické views boli neskôr nahradené produkčným Today/detail UI.
11. ~~Night picker + dátová korektnosť baseline pre historické noci~~ ✅
    (2026-07-25) — over overené: `BaselineTracker`/`HRVStatus`/`RHRStatus`/
    `SpO2Status` boli **už od začiatku referenceDate-aware** (žiadny
    `Date()` v MetricsCore), zmena nebola v MetricsCore potrebná. Jediná
    "teraz" závislosť bola v app-layer `HRVIntegration`/`SpO2Integration`
    (`let now = Date()`), tam pridaný `referenceDate: Date = Date()`
    parameter do `run()`/`computeXStatus()`. `MetricsOverviewView` má
    Digital Crown wheel Picker (posledných 14 nocí) — zvolený pred List+
    NavigationLink, lebo požiadavka bola "táto istá obrazovka sa prekreslí"
    pre zvolenú noc, nie presun na nový screen; wheel Picker je štandardný
    watchOS vzor pre výber z malej množiny hodnôt na jednej obrazovke.
    Loading state (`isLoading`), cancellation guard (`Task.isCancelled`)
    proti rýchlemu prescrollovaniu prepisujúcemu novšie dáta staršími,
    "Medián za noc" label a "Noc D.M.–D.M." rozsah pridané do
    HRVStatusView/SpO2StatusView/MetricsOverviewView.
12. ~~UI polish (pôvodný diagnostický scaffold)~~ ✅ (2026-07-25) — historický
    vizuálny beh, žiadna zmena v Sources/MetricsCore. `AppTheme.swift`
    (indigo/teal paleta z app ikony, oddelené traffic-light farby pre
    normal/low/critical) a `MetricCard.swift` (zdieľaná karta s pevnou
    výškou obsahu, aby loading/empty/plný stav nemenili layout — appka
    "neskáče"). HRV/SpO2 teraz card-based, SF Symbols (`waveform.path.ecg`,
    `drop.fill` — nie `lungs.fill`, ten sedí skôr na budúcu dychovú
    frekvenciu M12), animovaná farba indikátora pri zmene levelu, tichý
    pulzujúci skeleton pri loadingu (nie spinner). Night picker prerobený
    z wheel Picker (zaberal primárny priestor) na kompaktný "‹ label ›"
    stepper, nech sú obe karty viditeľné at-a-glance bez scrollovania.
    **Vedľajší nález**: build zlyhával na "does not contain a scheme
    named HealthKitDiagnostics" — príčina: `xcuserdata/.../
    xcschememanagement.plist` malo `SuppressBuildableAutocreation` pre
    HealthKitDiagnostics target (asi vedľajší efekt manuálnej úpravy scheme
    v predošlom behu kvôli LLDB/Debug executable). Zmazané (lokálny,
    gitignored, xcodegen-nespravovaný súbor) — scheme sa teraz opäť
    auto-vytvára, ale **bez uloženého .xcscheme súboru**, takže "Debug
    executable" je na Xcode default (zapnuté), nie explicitne vypnuté ako
    predtým — ak sa LLDB symbolikačný problém vráti, treba to znova vypnúť
    v Xcode GUI (Edit Scheme → Run → Info).
13. ~~Produkčný UI milestone~~ ✅ (2026-07-26) — pôvodný target prebudovaný
    na Watch Metrics product shell; aktuálny stav je v sekcii vyššie.
14. ~~Nočné okná + produkčné RR/RMSSD čítanie + audit~~ ✅ (2026-07-26) —
    HRV a SpO₂ sú filtrované presným intervalom hlavného spánku, historické
    noci majú vlastné intervaly a baseline nemá target/future leakage.
    `HeartbeatSeriesService` mapuje kumulatívne heartbeat eventy na RR bez
    premostenia `precededByGap` alebo hraníc sérií, používa
    `RRArtifactFilter` a RMSSD agregáciu bez cross-series rozdielu; chráni
    cancellation aj viacnásobné completion callbacky. Watch-only audit UI
    sumarizuje SDNN/RMSSD a validačný nočný pulz za 28 nocí. Automatizované
    testy neobsahujú osobné dáta; výsledné pokrytie treba odčítať na fyzických
    hodinkách pred rozhodnutím o HRV Status 2.0.
15. ~~HRV 2.0 — produkčný kombinovaný detail SDNN + RMSSD~~ ✅ (2026-07-28) —
    9-nočný audit potvrdil SDNN 8/9 a RMSSD 7/9 nocí, s mediánom 4 heartbeat
    série a 142 RR intervalov/noc. `RMSSDStatus` v MetricsCore používa rovnakú
    osobnú ±10 % HRV konvenciu a vlastnú 7/28-dňovú baseline; agreement insight
    iba vysvetľuje zhodu smerov. `DailyOverviewStore` načíta najviac 28 platných
    RMSSD nocí cez presné intervaly hlavného spánku. `BriefRunner`,
    `RecoverySignal` a notifikačné časovanie zostali bez RMSSD.
16. ~~App Store release hardening 1.0~~ ✅ (2026-07-28) — doplnené EN/SK
    katalógy a lokalizované notifikácie, Debug-only interné nástroje, privacy
    manifesty, build 2 a `SKIP_INSTALL = NO` pre skutočný watch-only archive
    payload. Návrhy metadát, privacy/review odpovedí a screenshotov sú v
    `docs/app-store/`.

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
