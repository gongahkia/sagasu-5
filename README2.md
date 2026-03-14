# `README2`

This file captures the README details that were added or changed during this editing session after `README.md` was restored to its earlier state.

## Added Or Changed Notes

* Added a macOS CI badge and documented `.github/workflows/macos-ci.yml`.
* Added a `SagasuCore` pure-logic layer description for scheduler, parser, merge, diagnostics, and scrape-config code.
* Updated the architecture description to show the helper loop calling into the pure scraper core.
* Added runtime notes for user launch-agent install/start/stop/remove controls from the app.
* Added runtime notes for retry-backed native WebKit scrapes and failure diagnostics.
* Changed the Objective-C bridge description from a placeholder boundary to the WebKit runtime owner for synchronous automation and PNG snapshots.
* Added a data note that failed native scrape attempts write artifacts under Application Support in `diagnostics/`.
* Added CI notes that the macOS workflow builds both executables, runs `swift test`, and builds the `.app` bundle.

## Relevant Files

* `.github/workflows/macos-ci.yml`
* `Sources/Core/LegacyParsing.swift`
* `Sources/Core/RefreshScheduler.swift`
* `Sources/Core/ScrapeDiagnosticsStore.swift`
* `Sources/Core/ScraperConfig.swift`
* `Sources/Core/SnapshotMergeLogic.swift`
