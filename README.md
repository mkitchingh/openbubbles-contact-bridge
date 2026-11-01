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
- Windows CI that analyzes and tests the reconciliation engine.
- a Windows setup wizard that discovers packages and profiles dynamically and
  produces a redacted diagnostic through native dialog boxes.

The next milestone is the ObjectBox adapter. It will remain dry-run-only until
the Store database schema has been validated against the public 1.x model.

The adapter now includes schema-compatible read-only inspection logic, but it
will only open a hash-verified snapshot created by the bridge. It refuses a live
profile path or an unmarked database.

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

## Development

Requires Dart 3.4 or newer.

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

