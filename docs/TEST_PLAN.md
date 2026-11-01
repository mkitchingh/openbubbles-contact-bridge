# Test plan

## Automated

- vCard line unfolding and case-insensitive UID parsing
- href fallback when UID is absent
- namespace separation between UID and href IDs
- email normalization
- phone normalization
- preservation of existing database row IDs
- insertion of new stable contacts
- removal of legacy empty-ID, non-shared contacts
- preservation of shared contacts
- unique handle matching
- no mutation for ambiguous handle matches
- PowerShell 5.1 package, profile, database, snapshot, and cleanup discovery
- compiled Windows inspector against a real temporary ObjectBox database
- report scan proving planted contact, phone, and email values are absent
- packaged-file SHA-256 manifest generation

## Store-build validation (read-only)

1. Close OpenBubbles and confirm Task Manager shows no process.
2. Run `Get-OpenBubblesStatus.ps1`.
3. Compare the reported ObjectBox model fingerprint with the public 1.x model.
4. Run `Backup-OpenBubblesData.ps1`.
5. Confirm the source and backup file counts and SHA-256 manifests match.
6. Launch the original Store app and confirm iMessage still works.

## Write-adapter acceptance gate

No release may enable `--apply` until all of the following are true:

- a disposable copy of the Store database opens with the proposed model;
- a dry run reports expected contact/handle counts without personal values;
- the copy survives write, close, reopen, and invariant verification;
- restoring a generated backup has been tested;
- the original Store app opens the modified disposable profile successfully;
- `--apply` requires explicit confirmation and cannot run while the app is open.

