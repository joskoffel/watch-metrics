# Watch Metrics 1.0 — App Store release checklist

This document is a draft for the owner. It does not authorize an upload or submission.

## Privacy policy drafts

### English

Watch Metrics processes selected Apple Health data on the user’s Apple Watch to present sleep duration, HRV (SDNN and RR-derived RMSSD), resting heart rate, blood oxygen, personal baselines, history, recovery context, and an optional morning brief.

Health data is read only after the user grants HealthKit access. It is processed and retained on-device as needed for app functionality. Watch Metrics does not transmit health data or other personal data to the developer or third parties. The app has no account, analytics, advertising, tracking, purchases, subscriptions, location access, or external service.

The app stores only local operational state, such as morning-brief delivery and diagnostic scheduling state. The complication does not access HealthKit. Users can change HealthKit and notification permissions in system settings and may delete the app to remove its local app data.

Watch Metrics is not a medical device and is not intended to diagnose, prevent, monitor, or treat any condition.

Privacy contact: **[OWNER REQUIRED: privacy email]**  
Controller/seller: **[OWNER REQUIRED: legal name and postal contact]**  
Effective date: **[OWNER REQUIRED]**

### Slovak

Watch Metrics spracúva vybrané údaje zo Zdravia na Apple Watch používateľa, aby zobrazil dĺžku spánku, HRV (SDNN a RMSSD odvodené z RR intervalov), pokojový pulz, okysličenie krvi, osobné baseline, históriu, kontext regenerácie a voliteľný ranný brief.

Zdravotné údaje sa čítajú až po udelení prístupu do HealthKit. Spracovanie a potrebné uloženie prebieha na zariadení. Watch Metrics neposiela zdravotné ani iné osobné údaje vývojárovi alebo tretím stranám. Aplikácia nemá účet, analytiku, reklamy, sledovanie, nákupy, predplatné, prístup k polohe ani externú službu.

Aplikácia lokálne ukladá iba prevádzkový stav, napríklad stav doručenia ranného briefu a diagnostiku plánovania. Komplikácia nepristupuje k HealthKit. Povolenia Zdravia a notifikácií možno zmeniť v systémových nastaveniach; odinštalovanie odstráni lokálne údaje aplikácie.

Watch Metrics nie je zdravotnícka pomôcka a nie je určená na diagnózu, prevenciu, monitorovanie ani liečbu ochorení.

Kontakt pre súkromie: **[VYŽADUJE VLASTNÍKA: e-mail]**  
Prevádzkovateľ/predajca: **[VYŽADUJE VLASTNÍKA: právny názov a poštový kontakt]**  
Dátum účinnosti: **[VYŽADUJE VLASTNÍKA]**

Publish these drafts at owner-controlled HTTPS URLs and enter the localized privacy-policy URLs in App Store Connect.

## App Privacy questionnaire recommendation

Reconfirm this against the final archived binary and every included third-party SDK:

- Tracking: **No**
- Data collected by the developer or third parties: **No**
- Health and fitness data: processed only on-device; do **not** mark it as collected while no data leaves the device
- Analytics, advertising, product personalization, or third-party advertising: **None**
- Privacy choices URL: optional because there is no account or collection
- Privacy policy URL: **[OWNER REQUIRED, mandatory]**

The app and extension manifests explicitly declare no tracking and no collected data. The app declares `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` because its defaults are accessible only to the app itself. The extension does not use a required-reason API.

## Age-rating questionnaire recommendation

Answer the current questionnaire factually in App Store Connect:

- In-app controls and social/communication capabilities: **No**
- Advertising, user-generated content, unrestricted web access: **No**
- Violence, sexuality, profanity, substances, gambling, contests, loot boxes: **None/No**
- Medical or Treatment Information: **None** — the app gives no diagnosis, treatment, medication, or condition-management guidance
- Health or Wellness Topics: **None** if the released copy remains descriptive only and gives no self-care, diet, or exercise recommendations
- Made for Kids: **No**
- Age-category override: **Not applicable**

Let App Store Connect calculate the final global and regional ratings. Do not hard-code a predicted age rating in marketing copy.

## Regulated medical-device declaration

Because the primary category is Health & Fitness and availability includes the EU/EEA, UK, and US, complete the regulated-medical-device declaration for each requested region:

- Recommended answer: **Not a regulated medical device**
- Basis: the app provides personal, descriptive wellness context and expressly does not diagnose, prevent, monitor, or treat disease
- Do not claim certification, clinical accuracy, medical alerts, or regulated status

Final legal classification remains the owner’s responsibility.

## Export compliance

The audited source contains no custom or non-exempt encryption and no networking. `ITSAppUsesNonExemptEncryption = NO` is set for the app and complication. Recommended App Store Connect answer: the app does not use non-exempt encryption and no export documentation is required. The owner remains responsible for the final legal answer if dependencies change.

## Commercial and availability setup

- Primary category: **Health & Fitness**
- Secondary category: leave empty unless the owner has a reason to add one
- Price: **Free**
- In-app purchases/subscriptions: **None**
- Availability: select **all countries and regions**, then review any local regulatory prompts
- Pre-order: **Off**
- Custom license agreement: use Apple’s standard EULA unless the owner supplies legal advice
- Legal seller/developer name: **[OWNER REQUIRED]**
- DSA: **[OWNER REQUIRED: declare trader/non-trader status; provide verified details if trader]**
- Support URL and email: **[OWNER REQUIRED]**
- Privacy-policy URLs (English and Slovak): **[OWNER REQUIRED]**

## Screenshot plan

Apple currently accepts these watchOS screenshot sizes: 422×514, 410×502, 416×496, 396×484, 368×448, or 312×390 pixels. Use **one size consistently across both localizations**. Recommended master set: **422×514 px** from the largest supported simulator, with a separate 368×448 QA pass for the smaller layout.

Capture the same five frames in English and Slovak, with realistic, internally consistent data and no developer menu:

1. **Today — complete data:** recovery hero plus the four metric tiles.  
   EN caption: “Your morning, in personal context”  
   SK caption: „Vaše ráno v osobnom kontexte“
2. **Nightly HRV:** SDNN, RR-derived RMSSD, agreement insight, and valid trend.  
   EN: “Two HRV signals, clearly explained”  
   SK: „Dva HRV signály, zrozumiteľne“
3. **Sleep detail:** main-sleep duration and context.  
   EN: “See the sleep that shaped your morning”  
   SK: „Spánok, ktorý tvorí váš ranný kontext“
4. **History:** several realistic complete and partial days.  
   EN: “Follow your own recent history”  
   SK: „Sledujte svoju nedávnu históriu“
5. **Settings or complication:** public Settings with morning-brief state, or an actual watch face showing the complication.  
   EN: “A brief when your morning is ready” / “One tap from your watch face”  
   SK: „Brief, keď je ranný prehľad pripravený“ / „Jedno klepnutie z ciferníka“

Rules:

- Capture native UI; do not add fabricated medical alerts, scores, or live-monitoring claims.
- Do not show HRV Data Audit, HealthKit diagnostics, morning-brief debug, raw errors, notification test actions, permission sheets, or personal identifiers.
- Keep values physiologically plausible and consistent across Today and detail screens.
- Use the same frame order and screenshot dimensions for English and Slovak.
- Verify text at larger Dynamic Type before capturing the default-size marketing set.

## Final owner checklist before upload

- [ ] Supply every owner-required URL, email, legal name, review contact, copyright, and DSA field.
- [ ] Verify the paid Apple Developer Program team, distribution certificate, and App Store provisioning.
- [ ] Create/confirm App IDs `com.watchmetrics.WatchMetrics` and `com.watchmetrics.WatchMetrics.Widget`.
- [ ] Confirm HealthKit entitlement for the app and no HealthKit entitlement for the widget.
- [ ] Confirm version 1.0 and build 2 have not already been uploaded; increment build if necessary.
- [ ] Run signed smoke tests on supported Apple Watch hardware.
- [ ] Capture and review both screenshot localizations.
- [ ] Reconfirm App Privacy, age rating, medical-device, and export answers against the final archive.
- [ ] Validate the archive in Organizer.
- [ ] Upload only after separate owner authorization.

## Apple references

- Screenshot specifications: <https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications>
- App privacy: <https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/>
- Privacy manifests: <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files>
- Age-rating definitions: <https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions>
- Regulated medical-device declaration: <https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status>
- Export compliance: <https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance>
