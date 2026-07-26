# Codex instructions

Tento súbor je vstupný bod pre OpenAI Codex CLI. Zdrojom pravdy pre
projektové pravidlá zostáva `CLAUDE.md`; nekopíruj jeho celý obsah sem.

## Pred každou úlohou

1. Prečítaj a dodržiavaj `CLAUDE.md`.
2. Prečítaj relevantné súbory v `docs/`, vždy najmä
   `docs/project-status.md`.
3. Skontroluj `git status` a zachovaj všetky cudzie rozpracované zmeny.
4. Ak má na rovnakých necommitnutých zmenách súčasne pracovať iný agent,
   nezačínaj ani nepokračuj, kým sa práca bezpečne neoddelí alebo
   necommitne.

## Nevyjednateľné pravidlá

- Rešpektuj architektúru `MetricsCore`: musí zostať čistá,
  deterministická a bez `HealthKit`, `SwiftUI`, `CoreLocation`, `Date()`,
  I/O a interného mutable stavu.
- Používaj TDD: najprv napíš zlyhávajúci test, potom implementáciu. Po
  každej zmene spusti `swift test --parallel`.
- Nemeň existujúce dizajnové ani architektonické rozhodnutia bez
  checkpointu s používateľom a jeho výslovného potvrdenia.

## Ukončenie úlohy

Reportuj stručne vo formáte určenom v `CLAUDE.md`. Na konci vždy uveď
výstup alebo presný súhrn:

- `git status`
- `git log origin/main..HEAD`

Ak zostávajú commity alebo iné zmeny iba lokálne, výslovne pripomeň, že
ich treba pushnúť.
