# Architecture

## Constraints

The Store build and a separately compiled Flutter build are not interchangeable.
The Store package owns protected state used for iMessage registration, while the
portable app has a different identity and key-store context. ObjectBox also does
not support concurrent access from unrelated processes.

The bridge therefore runs before OpenBubbles and follows this sequence:

1. Confirm `bluebubbles_app.exe` is not running.
2. Discover the Store package by package family name, not a hard-coded username.
3. Validate the database model fingerprint and supported app version.
4. Copy the entire ObjectBox directory to a timestamped backup.
5. Fetch contacts through a separate Google OAuth session.
6. Compute stable contact IDs from vCard UID (or href as fallback).
7. Reconcile contact rows and repair handle-to-contact relations in one
   ObjectBox write transaction.
8. Re-open the database read-only and verify row/relation invariants.
9. Launch the original Store app through its registered application ID.

Steps 4-9 are not enabled in the first milestone.

## Stable identity

The stable key is:

```text
carddav-uid:<unfolded UID value>
```

If a standards-compliant vCard has no UID:

```text
carddav-href:<absolute card URL>
```

The href fallback is deliberately namespaced so it cannot collide with native
or shared-contact IDs.

## Reconciliation invariants

- At most one non-shared contact exists for a stable ID.
- Existing ObjectBox row IDs are preserved when a stable contact is updated.
- Shared contacts are not deleted or repurposed.
- Every handle is linked to at most one contact.
- Email matching is case-insensitive.
- Phone matching uses digits plus a leading `+`; suffix matching is deferred to
  the adapter because it must mirror the exact OpenBubbles locale behavior.
- An ambiguous address match is reported and left unchanged.

## OAuth distribution

A public desktop application cannot keep an OAuth client secret confidential.
The production bridge should use its own Google OAuth project and consent screen,
store refresh credentials with Windows Credential Manager/DPAPI, and request only
the CardDAV scope. Reusing OpenBubbles' OAuth client is intentionally out of scope.

