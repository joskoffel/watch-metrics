# Watch Metrics 1.0 — English App Store copy

## Product page

- **App name:** Watch Metrics
- **Subtitle:** Personal recovery context
- **Primary category:** Health & Fitness
- **Price:** Free
- **Availability:** Worldwide

### Promotional text

See sleep, HRV, resting heart rate, and blood oxygen in the context of your own history—right on Apple Watch.

### Description

Watch Metrics turns selected Apple Health data into a calm, personal morning overview on Apple Watch.

The recovery signal brings together your existing nightly HRV and resting heart rate status. It is a conservative, qualitative interpretation—not a score and not a diagnosis. Each underlying metric remains visible, so you can understand the context behind the result.

Explore:

- main-sleep duration;
- nightly SDNN from Apple Health;
- RR-derived RMSSD from valid heartbeat series;
- resting heart rate;
- blood oxygen during main sleep;
- personal 7-day and 28-day baselines;
- recent history for valid days;
- an optional morning brief notification;
- a complication that keeps Watch Metrics close at hand.

RMSSD complements SDNN and never replaces it. When data or a personal baseline is not yet sufficient, Watch Metrics says so instead of substituting population norms.

All health processing stays on your Apple Watch. Watch Metrics has no accounts, analytics, ads, tracking, purchases, or subscriptions.

Watch Metrics is not a medical device and does not diagnose, prevent, monitor, or treat any condition. It does not provide medical alerts. Apple Watch and Health availability vary by device, region, permissions, and recorded data.

### Keywords

recovery,HRV,SDNN,RMSSD,sleep,resting heart rate,blood oxygen,SpO2,Health,Apple Watch

### What’s New in 1.0

Welcome to Watch Metrics.

- Personal recovery context from HRV and resting heart rate
- Sleep, SDNN, RR-derived RMSSD, resting heart rate, and SpO₂ details
- Personal baselines and recent history
- Optional morning brief
- Apple Watch complication
- English and Slovak

### Support text

For help with installation, Apple Health permissions, notifications, or interpreting unavailable data, contact **[OWNER REQUIRED: support email]** or visit **[OWNER REQUIRED: support URL]**.

Watch Metrics only reads supported Apple Health data after you grant access. If a metric is unavailable, check the Health app, device support, and whether enough recent data exists for a personal baseline.

## App Review notes

Watch Metrics is a watch-only app. It reads sleep analysis, HRV SDNN, resting heart rate, blood oxygen, and heartbeat series from HealthKit. Heartbeat series and its parent SDNN type are requested together. HealthKit access is read-only.

The app calculates personal context entirely on-device. It has no account, server, analytics, advertising, tracking, purchases, subscriptions, or location access. The complication does not query HealthKit and only opens the app’s daily overview.

The morning brief uses a HealthKit sleep observer and watchOS background refresh as wake-up opportunities. Delivery remains best-effort under watchOS. A deterministic local-notification fallback is armed only after the app resolves a non-provisional main sleep and the existing policy approves a future delivery time. Partial sleep never forces early delivery.

To review:

1. Install on a paired Apple Watch with compatible Apple Health data.
2. Open Watch Metrics and grant the requested read access.
3. Open the metric tiles for details and history.
4. Notification permission is optional; denial leaves the dashboard usable.

Internal HealthKit diagnostics, HRV Data Audit, morning-brief debug state, and notification test actions are compiled behind `DEBUG` and are unreachable in the submitted Release build.

Reviewer contact: **[OWNER REQUIRED: review contact name, phone, and email]**

## Owner-supplied fields

- Privacy policy URL: **[OWNER REQUIRED]**
- Support URL: **[OWNER REQUIRED]**
- Support email: **[OWNER REQUIRED]**
- Legal seller/developer name: **[OWNER REQUIRED]**
- Copyright holder and year: **[OWNER REQUIRED]**
- App Review contact details: **[OWNER REQUIRED]**
- DSA trader status and, if applicable, verified address/contact details: **[OWNER REQUIRED]**
