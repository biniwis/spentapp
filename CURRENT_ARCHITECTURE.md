# SPENT — Current architecture

Updated: 2026-09-10. This is the authoritative architecture reference. Historical product/UI proposals do not override the implementation described here.

## Build and tests

- `MoneyCity.xcodeproj` and its shared `MoneyCity` scheme are the build source of truth. Make incremental changes in Xcode and keep them in version control.
- `generate_xcodeproj.py` is frozen: invocation exits before any writes. Its old implementation is retained only for reference.
- `MoneyCityTests` is an iOS unit-test target in the shared scheme. Run Product → Test on an iOS simulator, or:
  `xcodebuild -project MoneyCity.xcodeproj -scheme MoneyCity -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- The old Swift package includes iOS UI sources and is not a supported macOS `swift test` entry point. It is not the release validation path.
- `behavioral_simulation.js` is historical behavioral simulation, not validation of Swift or App Intents.

## Wallet ingestion

Both Wallet App Intents and inline notification amount completion call `WalletIngestCoordinator.run`. It owns user feedback and diagnostic logging. `IngestStateMachine`, in the same source file, owns the synchronous main-actor transition:

`received → normalized → pending | finalized | duplicate | rejected | failed`

`TransactionIngest` remains a parsing/classification utility. `PendingWalletStore` remains a locked UserDefaults-backed pending store. Splitting these responsibilities does not create separate save paths.

- Duplicate lookup and SwiftData commit have no intervening suspension. A dedicated ModelContext isolates ingest rollback from UI edits.
- Pending completion is revalidated, classified and converted using the same rules as a complete report. Unknown merchants and currency/refund review requirements are preserved.
- Completion uses the pending UUID as the saved transaction UUID. Save happens before pending removal. A retry after a crash between these operations can recognize the saved UUID.
- A failed save rolls back its context and keeps the pending request for retry. Database failures are no longer described as missing Wallet fields.
- Diagnostics include the ingest UUID and state trace. Pending creation, completion and its transaction share a UUID. Independent full reports without a provider event ID still rely on the duplicate heuristic.
- Duplicate comparison uses normalized merchant, signed original amount, canonical original currency and an inclusive rolling 15-second window. Conversion to the base currency must not change identity. Charges and refunds are distinct.
- Pending matching uses normalized merchant, canonical currency and the same time window. It does not use time buckets or distinguish Intent names.

Limitations: without a stable provider event ID, identical legitimate purchases within the window can collide. The lock/main actor protects this process, not multiple independent writer processes. Pending storage and SwiftData are separate persistence systems; this is not a cross-store atomic transaction. Pending retention is currently 48 hours, purged on registration. These constraints must not be presented as exactly-once delivery.

## Swift ↔ renderer contract

`ThreeDioramaView.DioramaDataPayload` is Codable with `schemaVersion = 1`. `validateDioramaPayload` checks the version, required fields, finite numeric values and known/unique district and venue IDs before scene updates. Rendering/contract failures are reported through `dioramaError`; Swift records them, clears its sent-payload cache and asserts in Debug. Release does not intentionally crash on these reports.

`DioramaContractTests` encodes the actual Swift payload and executes the actual validator from the bundled HTML using JavaScriptCore. It also checks malformed envelopes. This complements runtime validation; it is not a WebGL rendering or visual test.

Financial storage, classification, conversion and month/venue aggregation live in Swift. The renderer still has presentation formulas driven by spending (building activity, traffic, reserve fill). Moving all these policies into explicit normalized visual fields is a future contract revision, not part of this repair.

## Diorama sources and lifecycle

Author `build_diorama.js` and the `city_v2_*.js` modules. Run `node build_diorama.js` to regenerate the bundled `MoneyCity/Resources/diorama.html`. Do not hand-edit generated HTML. This renderer builder is distinct from the frozen Xcode project generator.

Unclassified transactions use `city_sorting_hub`; miscellaneous transactions use `museum_curiosities`. Historical scaffolding specifications are not current behavior.

Existing lifecycle controls pause background rendering and dispose the renderer on teardown. Slot replacement disposes owned resources while preserving shared materials and removes detached animation references. Do not introduce indiscriminate material disposal. Repeated-month GPU memory behavior and physical-device Instruments profiling still require measurement; no leak-free or App Store readiness claim is made here.

## First-use city guidance (September 2026)

The city waits for real spending before presenting its building lesson. An empty month offers an expense-entry action; an empty historical month offers a return to the current month. The lesson waits until overlays, sheets, splash, pending payments and expense confirmation have cleared. Tapping a building or choosing the skip action records `hasSeenCityTapHint`.

`tutorialBuildingId` is an optional v1 payload field naming a spending venue. The renderer projects a 68px interactive marker from that venue's picking proxy. During the lesson a single tap opens the inspector, bypassing district-only navigation. The marker follows the camera and respects the CSS reduced-motion preference. The validator and Swift contract test cover valid and invalid tutorial IDs.

`SpentEmptyState` (in `ShimmerLoading.swift`) supplies shared branded empty states for history, analytics, recurring expenses and transaction feeds. History distinguishes an empty period from active filters with no results and offers filter clearing. The city header shows the month rather than the former hardcoded 12% change.

Visual verification performed on an iPhone 17 simulator in Hebrew: empty city → add synthetic expense → contextual lesson → tap the actual marker → correct building inspector. Physical-device performance, full VoiceOver and accessibility text-size coverage remain separate QA work.

## Monthly editorial recap

`MonthlyRecapSheet` renders a native SwiftUI story with five anchors and up to two ranked,
non-overlapping insights. It no longer embeds the Three.js diorama. `RecapSceneFrame` is a
pure, time-driven composition shared by onscreen presentation and the exported portrait.
The sequence is manual; scene animation settles and holds rather than advancing the slide.
Reduce Motion/VoiceOver show a completed frame. Backgrounding pauses the clock.

`MonthlyRecapInsightSelector`, beside `MonthlyRecapService`, owns eligibility and scoring.
Views receive typed facts. Fixed expenses/savings are excluded from purchase stories,
weak signals are omitted, and incomplete months do not get full-month comparisons.
The exact next-month boundary is excluded from recap totals. See `MONTHLY_RECAP_DESIGN.md`
for timing, selection thresholds, controls and sharing behavior.

## Historical references

`PRODUCT_SPEC.md`, `UI_SCREENS_SPEC.md`, and `APPLE_PAY_TESTING.md` are marked historical. The Apple Pay guide can inform manual testing, but platform assertions require revalidation on the test device. `SPENT_VISUAL_LANGUAGE.md` is a visual reference, not authority for runtime behavior. README is a project overview and points here for current architecture/testing.

## Store transfer and recovery

Store path lookup is read-only with respect to store contents. Startup first rolls back an
interrupted restore, applies an explicitly requested snapshot, then considers relocation.
Relocation only runs when the canonical store and its sidecars are absent and exactly one
legacy live location exists. Existing stores are never classified as empty by byte size.
Snapshots, recovered stores and corrupt-store quarantine directories are not automatic
relocation candidates. Ambiguity, invalid source data or transfer failure preserves the
originals and opens the existing visible memory-only mode rather than a new empty disk store.

Relocation and snapshot creation use SQLite's backup API to include committed WAL data.
The staged copy must pass `quick_check` and contain Core Data metadata; this is structural
validation, not a guarantee that every historical schema can migrate. The copy is closed in
DELETE journal mode and published as one file. Versioned container opens pass
`MoneyCityMigrationPlan`; the existing bare-schema recovery fallback remains explicit.

Explicit restore keeps a full original file set and an atomic rollback manifest before
changing the destination. Failure or interruption before commit restores that set before
opening SwiftData. Rollback copies originals, retaining them and the manifest if recovery
fails. Restore requests are cleared only on success. These operations require no other
process to have the destination open; cross-process live store replacement is unsupported.

City cache keys include merchant, building assignment, note, confirmation and savings-goal
identity as well as transaction ID, amount, category and timestamp.

Validation on 2026-09-10: `MoneyCityTests` passed 272 tests with zero failures on the
SPENT Round 1 Regression iOS 26.3 simulator. Eleven added regressions cover fresh and
synthetic unversioned stores, WAL transfer, ambiguous/corrupt sources, existing-store
preservation, orphaned sidecars, repeat relocation, restore rollback/interruption and city
cache edits. This does not replace testing archived stores from released builds or
physical-device profiling. SQLite backup contract: https://www.sqlite.org/backup.html.
