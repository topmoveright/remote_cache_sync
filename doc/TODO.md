# TODO: Production Hardening and Rollout Checklist

This document tracks items to complete as we integrate the adapters with real servers. All code comments remain in English per project preference.

## Global (All Adapters)

- [ ] Server time source
  - Wire authoritative server time for `getServerTime()`.
  - Prefer backend RPC/Function; avoid client clock skew.
- [ ] E2E with real SDKs
  - Minimal, deterministic end-to-end tests per backend (auth, RLS/permissions, network, sorting/cursor, pagination resume).
- [ ] Retry/Backoff & transient errors
  - Implement common retry middleware for 429/5xx/network with exponential backoff and jitter.
  - Classify errors (retryable vs non-retryable) and add structured logs.
- [ ] Pagination stability
  - Ensure stable ordering (e.g., updatedAt asc, id asc) to prevent duplicates/holes at page boundaries.
  - Define strict `since` semantics: rows with `updatedAt == since` are excluded.
- [ ] Idempotency & concurrency
  - Verify batch upsert/delete is idempotent; safe to re-run after failures/app restarts.
  - Guard against concurrent sync overlaps.
- [ ] Tombstones / hard delete strategy
  - If backend has no `deleted_at`, define how tombstones are produced and consumed.
- [ ] Metrics & observability
  - Wire `onParsePageStats` to logs/metrics (skip rate, page sizes, latency, error counts).
  - Add tracing spans for fetch/parse/apply phases.
- [ ] Persistent metadata (Drift)
  - Store last successful server timestamp / cursor per scope; restore on restart.
  - Tests for checkpointing and resume scenarios.
- [ ] Security & RLS validation
  - Validate scope injection against RLS policies; attempt cross-scope writes should fail as expected.
- [ ] Indexes & query plans
  - Confirm indexes exist to support `scope_name`, `updated_at`, and hot key lookups.

## Supabase

- [ ] Server time RPC/Edge Function
  - Set `SupabaseRemoteConfig.serverTimeRpcName` and validate `getServerTime()`.
- [ ] PostgREST ordering & keyset pagination
  - Adopt `order by updated_at asc, id asc`.
  - Consider keyset pagination for high-volume tables.
- [ ] RLS alignment
  - Ensure `scope_name`/`scope_keys` validations match JWT claims or relationships.
- [ ] E2E scenarios
  - Create a tiny fixture table and run real inserts/updates/deletes through the adapter.

## Appwrite

- [ ] Server time source (Function/API) and `getServerTime()` wiring.
- [ ] Query filters
  - Verify filters for scope + since behave as expected (strict `>` boundary).
- [ ] E2E scenarios with minimal mocked SDK (or dev project).

## PocketBase

- [ ] Server time source and wiring.
- [ ] Filter expressions
  - Confirm since + scope filter correctness and strict boundary.
- [ ] E2E scenarios with dev instance.

## Documentation

- [ ] Expand backend guides with concrete examples (queries, indexes, policies).
- [ ] Document operational runbooks (env vars, keys, rollback, failure handling).
- [ ] Reference tests that validate boundary cases and page aggregation.

## References (code)

- `AppwriteRemoteStore.parsePage`, `PocketBaseRemoteStore.parsePage`, `SupabaseRemoteStore.parsePage`
- `*RemoteStore.filterRowsByScope`
- `*RemoteStore.fetchSinceFromRawPages` (test-only helper)
- `onParsePageStats` in each `*RemoteConfig`
