# OpenBubbles Contact Bridge

A Windows companion for repairing Google/CardDAV contact identity and handle
links in the OpenBubbles 1.x Store app without replacing the app or touching
its Apple registration material.

## Status

**Early, safety-gated development. Do not use this repository to modify a live
OpenBubbles database yet.**

The repository currently contains:

- a pure Dart contact identity and reconciliation engine with tests;
- a read-only Windows diagnostic that locates the Store profile and ObjectBox
  files without printing credentials or message data;
- a backup helper that refuses to run while OpenBubbles is open;
- Windows CI that analyzes and tests the reconciliation engine;
- a Windows setup wizard that discovers packages and profiles dynamically and
  produces a redacted diagnostic through native dialog boxes;
- a schema-compatible, count-only ObjectBox inspector that can open only a
  hash-verified temporary snapshot, never the live Store database;
- a separate Google desktop OAuth/CardDAV dry-run planner that downloads
  vCards into memory and emits only aggregate repair counts;
- a snapshot-only repair rehearsal that performs and verifies the transaction
  on a disposable copy, then deletes that copy without opening live data.

The Store schema has now been validated read-only against a real 1.x profile.
The next safety gate is validating a Google repair rehearsal against a
temporary verified snapshot. No live-database repair writes
are enabled.

## Why a companion is necessary

OpenBubbles 1.x parses desktop CardDAV vCards into contacts whose `id` is an
empty string. Every fetched contact therefore collides with every other one,
which can overwrite contact details and attach handles to the wrong name.
The proposed upstream fix derives a stable ID from the vCard `UID`, falling
back to the card URL.

Replacing `app.so`, Flutter, or Rust DLLs inside the Microsoft Store package is
unsafe: the binaries are a matched, signed build, and the portable build cannot
inherit the Store package's protected Apple registration keys. This project
instead operates only on contact records while the original app is closed.

## Run the read-only diagnostic

Open PowerShell (not as Administrator), clone this repository, and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tools\Get-OpenBubblesStatus.ps1
```

For the guided Windows experience, including profile selection and a Save dialog:

```powershell
.\tools\Start-OpenBubblesBridgeSetup.ps1
```

The report contains paths, file sizes, schema fingerprints, and process state.
It deliberately excludes preference values, OAuth tokens, Apple IDs, messages,
and registration keys.

To create a consistent database backup while OpenBubbles is closed:

```powershell
.\tools\Backup-OpenBubblesData.ps1
```

To create the smaller, hash-verified ObjectBox snapshot accepted by the local
inspector:

```powershell
.\tools\New-OpenBubblesInspectionSnapshot.ps1
```

End users should download the `OpenBubbles-Contact-Bridge-Windows` workflow
artifact and double-click `Start-OpenBubblesDatabaseInspection.cmd`. It creates
and verifies a snapshot, runs the compiled inspector, saves a redacted
count-only report, and removes the temporary database copy automatically. If
the app starts or the source database changes during the copy, the operation
fails and removes the incomplete snapshot.

## Run the Google contact dry run

### Easier validation without Google Cloud setup

In Google Contacts, choose **Export**, select the contacts to test, and export
as **vCard (for iOS Contacts)**. Close OpenBubbles, extract the complete Windows
artifact, and double-click:

```text
Start-OpenBubblesVCardDryRun.cmd
```

Select the exported `.vcf` file and a destination for the redacted report. The
bridge reads the vCards in memory and produces the same aggregate plan without
OAuth or network access. Cards with a UID use the production stable-ID path;
cards without one use a local href fallback and are identified separately in
the report.

### Automated CardDAV validation

Create a Google **Desktop app** OAuth client and download its JSON as described
in [`docs/GOOGLE_OAUTH.md`](docs/GOOGLE_OAUTH.md). Then extract the complete
Windows artifact, close OpenBubbles including its tray icon, and double-click:

```text
Start-OpenBubblesGoogleDryRun.cmd
```

The wizard asks for the OAuth JSON and report destination, opens the system
browser for Google consent, fetches CardDAV vCards into memory, and calculates
aggregate repair counts against a verified database snapshot. It does not save
tokens or vCards and cannot modify the live or copied database.

## Development

Reproducible builds use Dart 3.13.7 and the committed dependency lockfile.

```powershell
dart pub get
dart test
```

## Development workflow

Changes are developed on feature branches and proposed through pull requests.
The repository owner squash-merges reviewed pull requests in GitHub's web UI,
keeping `main` concise and giving its commits GitHub's verified web signature.

## Safety promises

- Never copy or replace OpenBubbles executables or DLLs.
- Never read, export, or modify Apple registration/key-store material.
- Refuse database access while OpenBubbles is running.
- Create and verify a backup before any future write transaction.
- Default to dry-run and require an explicit write flag.
- Never log OAuth tokens, preference values, messages, or contact details.

This project is independent and is not affiliated with OpenBubbles, Apple,
Google, or Microsoft.

