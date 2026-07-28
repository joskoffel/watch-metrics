# Watch Metrics 1.0 — slovenské texty pre App Store

## Produktová stránka

- **Názov aplikácie:** Watch Metrics
- **Podtitul:** Osobný kontext regenerácie
- **Primárna kategória:** Health & Fitness
- **Cena:** Zadarmo
- **Dostupnosť:** Celosvetovo

### Propagačný text

Sledujte spánok, HRV, pokojový pulz a okysličenie krvi v kontexte vlastnej histórie — priamo na Apple Watch.

### Popis

Watch Metrics mení vybrané údaje zo Zdravia na pokojný, osobný ranný prehľad na Apple Watch.

Signál regenerácie spája váš existujúci stav nočnej HRV a pokojového pulzu. Je to konzervatívna kvalitatívna interpretácia — nie skóre ani diagnóza. Každá vstupná metrika zostáva viditeľná, aby ste rozumeli kontextu výsledku.

Preskúmajte:

- dĺžku hlavného spánku;
- nočný SDNN zo Zdravia;
- RMSSD odvodené z platných RR intervalov;
- pokojový pulz;
- okysličenie krvi počas hlavného spánku;
- osobné 7-dňové a 28-dňové baseline;
- nedávnu históriu platných dní;
- voliteľnú notifikáciu s ranným briefom;
- komplikáciu, vďaka ktorej máte Watch Metrics poruke.

RMSSD dopĺňa SDNN a nikdy ho nenahrádza. Keď ešte nie je dostatok dát alebo osobnej baseline, Watch Metrics to zrozumiteľne uvedie namiesto použitia populačných noriem.

Všetko spracovanie zdravotných údajov prebieha na Apple Watch. Watch Metrics nemá účty, analytiku, reklamy, sledovanie, nákupy ani predplatné.

Watch Metrics nie je zdravotnícka pomôcka a neurčuje diagnózu, nepredchádza, nemonitoruje ani nelieči žiadne ochorenie. Neposkytuje zdravotné upozornenia. Dostupnosť funkcií Apple Watch a Zdravia závisí od zariadenia, regiónu, povolení a zaznamenaných údajov.

### Kľúčové slová

regenerácia,HRV,SDNN,RMSSD,spánok,pulz,okysličenie,SpO2,Zdravie,Apple Watch

### Novinky vo verzii 1.0

Vitajte vo Watch Metrics.

- Osobný kontext regenerácie z HRV a pokojového pulzu
- Detail spánku, SDNN, RMSSD z RR intervalov, pokojového pulzu a SpO₂
- Osobné baseline a nedávna história
- Voliteľný ranný brief
- Komplikácia pre Apple Watch
- Angličtina a slovenčina

### Text podpory

Pomoc s inštaláciou, povoleniami Zdravia, notifikáciami alebo nedostupnými dátami získate na adrese **[VYŽADUJE VLASTNÍKA: e-mail podpory]** alebo **[VYŽADUJE VLASTNÍKA: URL podpory]**.

Watch Metrics číta podporované údaje zo Zdravia až po udelení prístupu. Ak metrika chýba, skontrolujte aplikáciu Zdravie, podporu zariadenia a či existuje dostatok novších údajov pre osobnú baseline.

## Poznámky pre App Review

Watch Metrics je aplikácia iba pre Apple Watch. Z HealthKit číta analýzu spánku, HRV SDNN, pokojový pulz, okysličenie krvi a heartbeat série. Heartbeat série a ich rodičovský typ SDNN žiada spoločne. Prístup do HealthKit je iba na čítanie.

Osobný kontext sa počíta výlučne na zariadení. Aplikácia nemá účet, server, analytiku, reklamy, sledovanie, nákupy, predplatné ani prístup k polohe. Komplikácia nepristupuje k HealthKit a iba otvorí denný prehľad.

Ranný brief používa HealthKit observer spánku a background refresh watchOS ako príležitosti na prebudenie. watchOS negarantuje presný čas spustenia. Deterministická lokálna notifikačná poistka vznikne až po vyriešení neprovizórneho hlavného spánku a schválení budúceho času existujúcou policy. Čiastočný spánok nikdy nevynúti skoré doručenie.

Interná HealthKit diagnostika, HRV Data Audit, debug ranného briefu a testovacie notifikačné akcie sú podmienene kompilované iba s `DEBUG` a v Release builde nie sú dostupné.

Kontakt pre review: **[VYŽADUJE VLASTNÍKA: meno, telefón a e-mail]**

## Údaje, ktoré musí doplniť vlastník

- URL zásad ochrany súkromia: **[VYŽADUJE VLASTNÍKA]**
- URL podpory: **[VYŽADUJE VLASTNÍKA]**
- E-mail podpory: **[VYŽADUJE VLASTNÍKA]**
- Právny názov predajcu/vývojára: **[VYŽADUJE VLASTNÍKA]**
- Držiteľ copyrightu a rok: **[VYŽADUJE VLASTNÍKA]**
- Kontaktné údaje pre App Review: **[VYŽADUJE VLASTNÍKA]**
- Status obchodníka podľa DSA a prípadné overené kontaktné údaje: **[VYŽADUJE VLASTNÍKA]**
