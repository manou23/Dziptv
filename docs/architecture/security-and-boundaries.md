# MESUT IPTV architecture and security notes

## Architecture migration

The Flutter client is being migrated incrementally:

- `domain/repositories` defines media-facing contracts.
- `data/datasources` contains Xtream protocol access.
- `data/repositories` adapts remote data to Domain.
- `presentation/providers` contains Riverpod providers for account-scoped media access and grid state.
- Existing screens are migrated in small groups to avoid changing the player, account flow, and cloud vault at the same time.

Legacy `Store` and account screens remain in place during the migration. They are not duplicated or replaced until their persistence and sync contracts have dedicated tests.

## Credentials and PINs

- Xtream credentials and the cloud session remain in `flutter_secure_storage`.
- The PIN is stored as a salted PBKDF2-HMAC-SHA256 hash; the PIN itself is not exported.
- PIN derivation is executed in a background isolate to avoid blocking Flutter's UI isolate.
- The cloud profile vault keeps its existing AES-GCM/PBKDF2 format for cross-device compatibility.

## Transport security

- The MESUT API URL must use HTTPS. The application continues to use the platform's normal TLS certificate-chain and hostname validation; certificate validation is never bypassed.
- Xtream providers may still supply HTTP stream endpoints. A global Android cleartext prohibition would break those providers, so MESUT API policy is enforced separately.
- SSL certificate pinning is intentionally not enabled yet. The current API uses a Render-managed hostname/certificate, and this repository does not currently contain verified primary and backup SPKI pins or a certificate-rotation process. Pinning without those items risks locking every user out after a legitimate certificate rotation. Before enabling pinning, move the API behind a stable controlled hostname, obtain and verify two SPKI pins, add a rotation/rollback procedure, and wire the pins into the release build.

## Cache lifecycle

- Catalogue responses have a five-minute TTL.
- Short EPG responses have a 90-second TTL.
- Cache keys are SHA-256 digests of credential-bearing request URIs, not plaintext URLs.
- The response cache is bounded and periodically pruned; the search-screen catalogue cache uses a separate six-entry LRU bound.
