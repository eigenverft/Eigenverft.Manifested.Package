# Team catalog trust — post-implementation findings

Review after v1 catalog-trust implementation, compared to [TEAM-CATALOG-TRUST.md](TEAM-CATALOG-TRUST.md). This file records the trust-only refactor decision and its implementation status.

**Design record:** [TEAM-CATALOG-TRUST.md](TEAM-CATALOG-TRUST.md)
**Backlog:** [PROJECT-TODO.md](PROJECT-TODO.md)

---

## Recommendation (implemented)

**Remove `PackagePublisherInventory.json` from the product model and runtime path.** Keep catalog authority in one place:

```text
PackageEndpointInventory     →  where JSON is found
definitionSignature          →  what was signed
PackageTrustInventory        →  which keys are trusted for which publisherId
PackageConfig.catalogTrust   →  strict, allowUnsignedPublisherIds, blockedPublisherIds
```

That is sufficient for strict production use, matches what v1 crypto enforces, and removes the false "trust the publisher name" story in README and `Add-TeamPackagePublisher`.

### Why this is the right simplification

1. **Trust rows are already publisher-scoped.** Each `keys[]` entry has `publisherId` + `keyThumbprint` + `certificatePem`. Verification checks signature thumbprint against that inventory. A second file repeating “publisher X is trusted” adds no crypto value under `strict`.

2. **v1 code already proves redundancy.** Under `strict`, a signed definition with a trusted key can win **without** a friendly publisher row (`unsigned` + `trusted: false` on the publisher still passes in tests). Publisher inventory is not the security gate; the key inventory is.

3. **Team UX gets simpler.** Onboarding becomes: endpoint + depot + **import signing key** + signed JSON. One mental model, one inventory file, commands named after keys/certs not “publisher trust.”

4. **The old model failed in practice.** README’s three-step flow (`Add-TeamPackagePublisher` then `Invoke-Package`) does not work on shipped `strict` defaults. That is a product bug caused by two overlapping “trust” concepts, not by missing publisher rows.

### What I would *not* do

- **Keep publisher inventory “for enable/disable only.”** Disabling a maintainer = set `enabled: false` or revoke keys for that `publisherId` in trust inventory, or add a small `blockedPublisherIds[]` in `PackageConfig` if you need a coarse switch without touching keys. That does not justify a whole parallel inventory.

- **Keep `unsignedExplicit` per publisher.** If unsigned catalogs are still needed for migration, use `catalogTrust.policy = allowUnsigned` plus `catalogTrust.allowUnsignedPublisherIds[]` in config, **not** `PackagePublisherInventory.json`.

- **Conflate endpoint trust with catalog trust.** Web endpoints may distribute trust differently (preseed, CI, future server policy); file shares need embedded signatures + local key inventory. That is deployment policy, not a reason to resurrect publisher inventory.

### Small gaps trust inventory does not cover today (fix in trust/config, not publisher file)

| Need | Suggested home |
| --- | --- |
| Block all keys for a `publisherId` quickly | Revoke/disable each key, or `blockedPublisherIds[]` in `PackageConfig` |
| Allow unsigned only for named publishers in migration | `allowUnsignedPublisherIds[]` under `catalogTrust` in `PackageConfig` |
| Shipped Eigenverft bootstrap | `trustSource: moduleShipped` on key row (already exists) |
| Multi-publisher same `definitionId` | Endpoint scan + conflict mode in `PackageConfig` (already exists) |

None of these require `trustMode`, `unsignedExplicit`, or `Add-TeamPackagePublisher`.

### Phased removal (practical)

| Phase | Action |
| --- | --- |
| 1 | **Docs:** README, TEAM-CATALOG-TRUST, findings — trust-only story; mark publisher commands deprecated |
| 2 | **Runtime:** `Resolve-PackageDefinitionCandidateTrustEligibility` uses signature + trust inventory + `catalogTrust` only; ignore missing publisher file |
| 3 | **Bootstrap:** stop copying/shipping `PackagePublisherInventory.json` |
| 4 | **Commands:** hard-deprecate `Add-TeamPackagePublisher`, `Add-PackagePublisher`, `Get-PackagePublisher`, ... |
| 5 | **Tests:** replace publisher-inventory fixtures with trust-inventory + config policy |

### Risks to accept

- **Breaking change** for anyone who only ran `Add-TeamPackagePublisher` on `allowUnsigned` machines — document `allowUnsigned` in config instead.
- **Refactor touch surface:** `DefinitionReference.ps1`, bootstrap, aggregation, export tests, module help strings.

---

## Executive summary

| Item | Status |
| --- | --- |
| Signing, canonical JSON, schema 1.7, trust commands | Good — keep |
| Shipped Eigenverft catalog under strict | 18/18 verify trusted (review snapshot) |
| Pester | 229 passed (review snapshot) |
| `PackagePublisherInventory.json` | **Recommend remove** — redundant with trust inventory under strict; harmful for docs/UX |
| v1 runtime | Aligned — no publisher inventory file required for definition resolution |

---

## Target model (three inventories + config)

| Question | Answer |
| --- | --- |
| Where are definitions? | `PackageEndpointInventory.json` |
| Who signed this file? | `definitionPublication.definitionSignature` |
| Is the key allowed for this `publisherId`? | `PackageTrustInventory.json` |
| Signed required? Unsigned allowed? | `PackageConfig.json` -> `catalogTrust.policy` + `allowUnsignedPublisherIds[]` |
| Payload integrity? | Hashes / Authenticode + `payloadVerification` |

```text
definition.publisherId + definitionSignature.keyThumbprint
        ↓
PackageTrustInventory (enabled key, not revoked)
        ↓
catalogTrust.policy
        ↓
winner selection → Invoke-Package
```

**Identity vs authority:** `publisherId` in JSON is a **label** in the signed payload. **Authority** is the trusted key row for that label.

---

## Today vs recommendation (v1 code)

| Scenario | v1 behavior | After refactor |
| --- | --- | --- |
| Eigenverft shipped defs | Key + publisher row | Key only |
| Team signed defs | Key + `Add-TeamPackagePublisher` / enable row | Key import + signed JSON |
| Unsigned team defs | `allowUnsigned` + `unsignedExplicit` | `allowUnsigned` plus `allowUnsignedPublisherIds[]` in config |
| Disable maintainer | Disable publisher | Disable/revoke keys or block `publisherId` in config |

---

## README and team workflow

**Today (misleading):**

```powershell
Add-TeamPackageDepot ...
Add-TeamPackageEndpoint ...
Add-TeamPackagePublisher -PublisherId 'My Team'
Invoke-Package -DefinitionId ...
```

**Recommended:**

```powershell
Add-TeamPackageDepot -BasePath '\\team-share\PackageDepot'
Add-TeamPackageEndpoint -BasePath '\\team-share\PackageEndpoint'
# Maintainer: New-PackageSigningCertificate -Name ...; Sign-PackageDefinition -Path ...
Import-PackageTrust -Path '<public-signing-cert.cer>'
Invoke-Package -DefinitionId 'MyPackage'
```

- Retire **`Add-TeamPackagePublisher`** from trust/onboarding docs.
- Document **`PackageTrustInventory.json`** and **`catalogTrust`** in the inventory table.
- **Strict file share:** signed 1.7 JSON + preseeded keys.
- **Web/central endpoint (future):** trust may be delivered beside JSON; strict offline clients still benefit from embedded signatures — stay neutral in agent/schema text.

---

## Agent / LLM authoring

1. Author semantic JSON; `definitionSignature.kind = unsigned` while drafting (no `signatureValue`).
2. Maintainer: `New-PackageSigningCertificate -Name ...` → `Sign-PackageDefinition -Path ...`.
3. Clients: `Import-PackageTrust -Path <public .cer>` — **not** publisher inventory commands.

Align schema `description` / `x-eigenverftAgentHint` with trust-only setup when those files are edited again.

---

## Alignment with TEAM-CATALOG-TRUST.md

The design doc’s v1 decision to **keep** `PackagePublisherInventory.json` for `unsignedExplicit` made sense during a transitional implementation. The trust-only refactor removes that implementer debt:

- TEAM-CATALOG-TRUST "What the product does today" and locked requirements are trust-only.
- This findings file remains the rationale for why endpoint = discovery, trust inventory = authority, and config = policy.

---

## Mental model

```text
Discovery:  PackageEndpointInventory
Authority:  definitionSignature + PackageTrustInventory
Policy:     PackageConfig.catalogTrust (strict, allowUnsignedPublisherIds, blockedPublisherIds)
Payload:    contentHash / publisherSignature
```

---

## Commands (recommended)

| Task | Command |
| --- | --- |
| Trust a team key | `Import-PackageTrust`, `Trust-PackageSigningCertificate` |
| Sign catalog JSON | `New-PackageSigningCertificate`, `Sign-PackageDefinition`, `Get-PackageSigningProfile` |
| Verify | `Verify-PackageDefinitionSignature`, `Verify-PackageDefinitionCatalog` |
| List / revoke / block | `Get-PackageTrust`, `Revoke-PackageSigningCertificate`, `Block-PackageSigningCertificate` |
| Migration unsigned only | `catalogTrust.policy = allowUnsigned` plus `catalogTrust.allowUnsignedPublisherIds[]` in `PackageConfig` |

**Do not document as trust:** `Add-TeamPackagePublisher`, `Add-PackagePublisher`.

---

## Changelog

| Date | Note |
| --- | --- |
| 2026-05-25 | Initial review |
| 2026-05-25 | Withdrew “two inventory layers” framing |
| 2026-05-25 | **Recommendation section:** trust-only model, phased removal, gaps → config/trust not publisher file; align with product direction |
| 2026-05-25 | Removed embedded backlog (P0/P1/P2) — backlog lives in `PROJECT-TODO.md` |
| 2026-05-25 | Updated after trust-only runtime refactor: publisher inventory removed from resolution/bootstrap; config allow/block lists are implemented. |
