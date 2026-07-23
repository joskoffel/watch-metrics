# Data availability report

Vygenerované: 2026-07-23T16:38:11  
Analyzované okno: posledných 90 dní (2026-04-24 – 2026-07-23)  
Celkovo záznamov v exporte: 2208811

## Súhrn dostupnosti

| Typ | Rola v pláne | Záznamov (okno) | Dní s dátami | Pokrytie |
|---|---|---|---|---|
| `HeartRateVariabilitySDNN` | M1/M2 – nočné HRV | 911 | 87/90 | 96.7% |
| `RestingHeartRate` | M3 – RHR baseline | 85 | 85/90 | 94.4% |
| `SleepAnalysis` | M4/M13 – spánok | 2615 | 90/90 | 100.0% |
| `RespiratoryRate` | M12 – dychová frekvencia | 4578 | 90/90 | 100.0% |
| `AppleSleepingWristTemperature` | M11 – teplota zápästia | 89 | 86/90 | 95.6% |
| `VO2Max` | M10 – VO2max trend | 23 | 23/90 | 25.6% |
| `OxygenSaturation` | M14 – SpO2 | 1409 | 87/90 | 96.7% |
| `HeartRate` | (kontext) – priebežné HR | 90486 | 90/90 | 100.0% |

## Nočná granularita (kľúčové pre M1/M2 – HRV status)

### M1/M2 – nočné HRV (`HeartRateVariabilitySDNN`)

- Nocí s aspoň 1 vzorkou: 84/90 (93.3%)
- Medián vzoriek/noc (spomedzi nocí, kde vôbec niečo je): 9.0
- Priemer vzoriek/noc: 8.35
- % nocí s ≥3 vzorkami: 92.2%
- % nocí s ≥5 vzorkami: 92.2%

### M12 – dychová frekvencia (`RespiratoryRate`)

- Nocí s aspoň 1 vzorkou: 90/90 (100.0%)
- Medián vzoriek/noc (spomedzi nocí, kde vôbec niečo je): 52.0
- Priemer vzoriek/noc: 50.87
- % nocí s ≥3 vzorkami: 100.0%
- % nocí s ≥5 vzorkami: 100.0%

### M11 – teplota zápästia (`AppleSleepingWristTemperature`)

- Nocí s aspoň 1 vzorkou: 89/90 (98.9%)
- Medián vzoriek/noc (spomedzi nocí, kde vôbec niečo je): 1
- Priemer vzoriek/noc: 1
- % nocí s ≥3 vzorkami: 0.0%
- % nocí s ≥5 vzorkami: 0.0%

### M14 – SpO2 (`OxygenSaturation`)

- Nocí s aspoň 1 vzorkou: 84/90 (93.3%)
- Medián vzoriek/noc (spomedzi nocí, kde vôbec niečo je): 15.0
- Priemer vzoriek/noc: 14.86
- % nocí s ≥3 vzorkami: 92.2%
- % nocí s ≥5 vzorkami: 92.2%

## Spánkové dáta (M4/M13)

- Nocí so záznamom spánku: 90/90 (100.0%)
- Priemerný počet segmentov (core/deep/REM/awake) za noc: 29.1
- Nájdené hodnoty spánkových stavov: ['HKCategoryValueSleepAnalysisAsleepCore', 'HKCategoryValueSleepAnalysisAsleepDeep', 'HKCategoryValueSleepAnalysisAsleepREM', 'HKCategoryValueSleepAnalysisAsleepUnspecified', 'HKCategoryValueSleepAnalysisAwake', 'HKCategoryValueSleepAnalysisInBed']

## HKHeartbeatSeries (surové RR intervaly pre RMSSD)

**Nenájdené.** Toto je OČAKÁVANÉ — "Export All Health Data" z Health appky spravidla neobsahuje surové RR intervaly (`HKHeartbeatSeriesSample`), aj keď ich hodinky merajú a HealthKit API k nim prístup má. Over dostupnosť priamo cez `HKHeartbeatSeriesQuery` v malej testovacej watchOS appke (Gate G0.2), nie cez tento export. Ak tam nič nebude, RMSSD odpadá a zostávaš na SDNN z Health appky.

## Odporúčanie na základe tohto reportu

Medián ≥5 vzoriek/noc — dobré. Denný HRV signál je realistický, M1/M2 môžeš stavať na dennej báze s bežným 7d kĺzavým oknom.