# Shared Cloud Lab — Phase 1

This is a Debug-only feasibility harness, not the production Shared ledger. It uses only
`SPENT.SharedLab.<UUID>` zones and `SharedLabExpense` sample records. No personal transaction,
budget, merchant rule, reward or backup service is called by the lab.

## Run

Build the MoneyCity Debug scheme, signed for a device with iCloud enabled. Debug now uses
`SharedLab.entitlements` (CloudDocuments + CloudKit, Development environment); Release retains
the existing entitlements. The developer team's provisioning profile must support CloudKit
for `iCloud.com.moneycity.app`. This change does not configure the Apple developer portal.
Debug also uses `SharedLab-Info.plist` with `CKSharingSupported`; its URL schemes and iCloud
Drive settings mirror the production plist. Keep those common settings aligned when editing them.

Open Profile → Shared Cloud Lab, or add `--shared-cloud-lab` to the launch arguments.
The lab only contacts iCloud after an explicit Connect / create / join / sync action.

## One focused two-account check

1. On account A, connect and create a test space. Use Invite / manage access to share privately
   with account B. Both devices must run a signed Debug build using Development CloudKit.
2. On B, open the invitation (cold and warm launch are supported by the scene delegate), then
   accept in the lab. Alternatively paste the invitation URL into the lab.
3. A adds a sample and taps Sync now. B refreshes and sees the same record ID and amount.
   B adds ₪1 to that record and syncs; A refreshes and sees the changed amount.
4. With a connected session, disconnect the network, add a sample, close/reopen the app, then
   reconnect and refresh/sync. Pending revisions should upload once with the original ID.
5. Delete a sample and sync. It is retained as a tombstone and disappears on the other device.
6. Use Apple's access-management sheet to remove B or leave on B. Refresh B: the space must
   disappear. The lab does not recreate a removed zone. Do not delete real shared data.

Record the result of each step; an unsigned simulator build proves compilation only.
Actual two-account, invitation, offline and revocation results are **not yet verified**.

Verified locally on 2026-09-23: unsigned Debug simulator build succeeds; the built app contains
`CKSharingSupported = true` and the scene manifest. No Simulator launch or generated test suite
was used. This does not verify provisioning or live CloudKit behavior.

## Implementation boundaries

- CKSyncEngine is the only transport queue; local dirty revisions repair the crash gap before
  state serialization. Private and shared database engines are separate and manually driven.
- Lab record archives, revisions and engine states are persisted together in an atomic JSON
  file under Application Support/SharedCloudLab/Development/<account hash>. They never use
  default.store, personal snapshots or iCloud Drive backups.
- Account changes stop the harness and require reopening. Existing account data remains
  isolated. Unreadable caches are reported, never silently replaced.
- Edits use server-wins on conflict; tombstones win stale edits. The production recovery-draft
  UX is not implemented by this lab.
- Background pushes, shared SwiftData models, product UI, currencies, members and transfers
  belong to later phases. A failed initial share creation can leave an empty lab zone, which
  can be inspected in CloudKit Console; there is no automatic broad cleanup.
- Access revocation cannot be observed while offline. Refresh requires connectivity.

Do not promote this sample record/cache format to the production schema. Use the observed
CloudKit behavior to implement SharedSchemaV1 and the separate shared.store next.
