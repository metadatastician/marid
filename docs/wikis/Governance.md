<!-- berrywiki
id: 01a115aa-ca2a-82fa-bd96-951dc1a6ede7
parent: 01a115aa-ca16-8134-837f-254d19a045bf
position: 60
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Governance

Who decides, who maintains, how security reports are handled, and which branch and tag rules are actually in force. Written from `GOVERNANCE.adoc`, `docs/GOVERNANCE.adoc`, `.github/GOVERNANCE.md`, `MAINTAINERS.adoc`, `docs/MAINTAINERS.adoc`, `.github/CODEOWNERS`, `.github/SECURITY.md`, `.github/CODE_OF_CONDUCT.md`, `.github/rulesets/README.adoc` and the two ruleset JSON files beside it. There is no root `SECURITY.md`, `SECURITY.adoc` or `CODE_OF_CONDUCT` file; both live under `.github/`. For how a change is made and merged, see [[Contributing]]; for the CI gates, see [[CI-and-Operations]].

## Governance model

The repository carries two descriptions that do not agree.

`.github/GOVERNANCE.md` is the fuller one. Marid follows a **Benevolent Dictator For Life (BDFL)** model, chosen for solo maintainers and small teams where consistent decisions matter more than formal consensus. The BDFL has final authority on technical direction, releases, contributor access and community standards. A transition clause says that when the core team exceeds three active maintainers the project should move to consensus governance with documented voting, and that the transition itself is recorded as an ADR in `docs/decisions/`.

| Role | From `.github/GOVERNANCE.md` |
|---|---|
| BDFL | Project creator and final decision-maker; sets direction; appoints and removes maintainers; responsible for RSR adherence |
| Maintainer | Commit access; reviews and merges PRs; triages issues; manages releases; upholds quality, security and the Code of Conduct; listed in `MAINTAINERS.adoc` |
| Contributor | Submits PRs, issues, discussions; no direct commit access; reviewed by maintainers |
| Bot | Automated review, scanning, dependency updates and standards enforcement; held to the same standards as humans; configured under `.machine_readable/bot_directives/` |

Decision procedure: routine changes (bug fixes, dependency updates, minor improvements) by any maintainer; significant changes discussed in an issue first, with a clear accept or reject from the BDFL and reasoning; significant technical decisions recorded as ADRs (`proposed`, `accepted`, `deprecated`, `superseded`, `rejected`). See [[Decisions]].

Becoming a maintainer: sustained quality contributions, understanding of RSR standards, constructive participation, and reliability over roughly three or more months; nominated privately by an existing maintainer, decided by the BDFL. Removal: twelve months of inactivity (with an offer of emeritus status first), a Code of Conduct violation, or BDFL discretion with privately documented reasoning. Amendments to the governance document are made by the BDFL, recorded as an ADR, and communicated to maintainers and contributors.

`GOVERNANCE.adoc` at the root and `docs/GOVERNANCE.adoc` are byte-identical to each other and describe a different, multi-maintainer procedure: minor changes by any maintainer; major changes (new features, architectural or API changes) discussed in issues or PRs and approved by at least two maintainers; breaking changes through an RFC, a majority of maintainers, and a migration guide. Both are dated "Last updated: 2026-07-18". With a one-person roster these thresholds cannot currently be met; the BDFL document is the one that matches the roster.

## Maintainers

`MAINTAINERS.adoc` (root) and `docs/MAINTAINERS.adoc` are identical and declare themselves the single roster, superseding earlier duplicates at `.github/MAINTAINERS` and `docs/attribution/MAINTAINERS.adoc`. The repository's GitHub owner is the `metadatastician` organisation.

| Name | Role | Contact |
|---|---|---|
| Jonathan D.A. Jewell | Lead Maintainer | `@hyperpolymath` on GitHub |

Maintainer responsibilities (from the roster): reviewing and merging PRs, triaging issues and feature requests, code quality and security standards, releases and versioning, the Code of Conduct, documentation and examples, and responding to security vulnerabilities. Questions about governance go in an issue.

`.github/CODEOWNERS` assigns `@hyperpolymath` as default owner of everything and names `SECURITY.md`, `.github/workflows/`, `Trustfile.deed` and `.machine_readable/` as requiring explicit review.

## Security policy

`.github/SECURITY.md` (policy version 1.0.0):

- Report through GitHub Security Advisories at `github.com/metadatastician/marid/security/advisories/new`; the fallback is email to `j.d.a.jewell@open.ac.uk` (unencrypted). Never report through public issues, PRs, discussions or social media.
- Response targets: initial response within 48 hours, triage within 7 days, status updates every 7 days, resolution and coordinated disclosure targeted at 90 days (targets, not guarantees; later by mutual agreement).
- Coordinated disclosure, with credit in the advisory unless anonymity is preferred. Safe harbour for good-faith research that follows the policy; it does not extend to third-party systems.
- In scope: this repository and its code, official releases, documentation that could lead to security issues, build and deployment configuration, and dependencies (reported here, coordinated upstream). Out of scope: third-party services, social engineering, physical security, DoS against production, known issues, theoretical issues without proof of concept.
- No monetary bounties, hardware or paid research contracts. Recognition in `SECURITY-ACKNOWLEDGMENTS.md`, advisories and release notes.
- Supported versions table: `main`, the latest release and the previous minor release receive fixes; older versions do not.
- Contributor practices: never commit secrets; use signed commits; review dependencies before adding them; run security linters locally.

## Code of Conduct

`.github/CODE_OF_CONDUCT.md` pledges a harassment-free experience for everyone regardless of age, disability, ethnicity, sex characteristics, gender identity and expression, experience, education, socio-economic status, nationality, appearance, race, caste, colour, religion, or sexual identity and orientation, and names psychological safety as a requirement of a thriving community. It applies to all project spaces. Enforcement is described in that document; `.github/GOVERNANCE.md` makes the BDFL the final arbiter in conduct disputes. A maintainer may be removed for a violation.

## Rulesets committed in the repository

`.github/rulesets/README.adoc` is explicit: **GitHub does not read this directory.** Unlike `.github/workflows/`, `.github/dependabot.yml` or `.github/settings.yml`, ruleset JSON in a repository path is not auto-applied by any GitHub feature. The files are documentation of intent plus a ready-to-POST payload. A ruleset takes effect only when someone applies it through the REST API or imports it in the web UI; per ADR-0003 the Configure stage is an operator stage done out of band, and automation for it is future work that must not be described as existing.

The two payloads present:

| File | Target | Rules |
|---|---|---|
| `.github/rulesets/Immutable-Tags.json` | All tags (`~ALL`), enforcement `active`, no bypass actors | `deletion`, `non_fast_forward`, `update`, `required_signatures` |
| `.github/rulesets/Optimus-Branch.json` | Default branch (`~DEFAULT_BRANCH`), enforcement `active`, no bypass actors | `deletion`, `non_fast_forward`, `required_signatures`, `pull_request` (2 approving reviews, dismiss stale reviews on push, code-owner review, last-push approval, review-thread resolution, extra approval for unattributed changes), `required_status_checks` (strict policy, empty required list) |

Apply, list and update commands from the README, with this repository's owner and name filled in:

```bash
# Apply (create) a ruleset:
gh api --method POST \
  -H "Accept: application/vnd.github+json" \
  "/repos/metadatastician/marid/rulesets" \
  --input .github/rulesets/Optimus-Branch.json

# List what is actually in force; the only authoritative answer:
gh api "/repos/metadatastician/marid/rulesets" --jq '.[] | "\(.id)\t\(.name)\t\(.enforcement)"'

# Update an existing ruleset in place (numeric id from the list above):
gh api --method PUT \
  "/repos/metadatastician/marid/rulesets/<id>" \
  --input .github/rulesets/Optimus-Branch.json
```

The README's closing warning: do not infer that a ruleset is active because the JSON is present. A ruleset that exists as a file but was never POSTed is the tag-protection equivalent of a check that cannot fail.

## Rulesets actually in force

Measured facts, as of this page's writing:

- The repository was transferred from the `hyperpolymath` user account to the `metadatastician` organisation on **2026-09-22**.
- It now inherits the organisation's rulesets: **Estate Baseline**, **EstateBranching** (`required_signatures` + `pull_request` + `code_scanning` (CodeQL) + `copilot_code_review`), **EstateTagging** and **EstatePushing**.
- **8 effective rules** are bound to `main`.
- The JSON files committed under `.github/rulesets/` are the estate canon, but committing a ruleset JSON does not apply it. They are **not** applied as repo-level rulesets; what binds `main` and the tags comes from the organisation.

Consequences for contributors (see [[Contributing]]): every commit on `main` must be signed (`required_signatures`), every change arrives through a pull request, CodeQL code scanning and Copilot code review are part of the branch rules, and tags are protected at the organisation level. The two-approver requirement written into `Optimus-Branch.json` is not what is in force.

Verify rather than trust this page: run the `gh api "/repos/metadatastician/marid/rulesets"` listing above for repo-level rulesets, and remember that organisation rulesets do not appear in that repo-level list.

## Known stale statements in the sources

- `.github/rulesets/README.adoc` documents a file called `tag-protection.json` (with an admin-role bypass, `actor_id: 5`) and uses it in every example command. No such file exists; the directory holds `Immutable-Tags.json` (no bypass actors) and `Optimus-Branch.json`.
- `GOVERNANCE.adoc` and `docs/GOVERNANCE.adoc` (identical, dated 2026-07-18) require two maintainer approvals for major changes and a maintainer majority for breaking changes; the roster has one maintainer and `.github/GOVERNANCE.md` describes BDFL governance. Two of the three governance documents are duplicates of each other and conflict with the third.
- `MAINTAINERS.adoc` at the root is a byte-identical copy of `docs/MAINTAINERS.adoc`, so its relative links (`../.github/CODE_OF_CONDUCT.md`, `../.github/CONTRIBUTING.md`, `attribution/CODEOWNERS.adoc`) resolve correctly only from `docs/`.
- `.github/GOVERNANCE.md` opens with an SPDX header of CC-BY-SA-4.0 and closes with "Copyright (c) 2026 hyperpolymath. Licensed under MPL-2.0"; its Bot section still reads "managed via your bot orchestration system" (template residue).
- `.github/CODEOWNERS` names a root `SECURITY.md` that does not exist (the policy is `.github/SECURITY.md`) and keeps the template comment "Replace hyperpolymath with your GitHub username or team".
- `Optimus-Branch.json` requires two approving reviews and code-owner review from a single-owner CODEOWNERS; even if it were applied, a one-maintainer project could not satisfy it without bypass.
- No `github.com/hyperpolymath/marid` URL, `.a2ml` citation, `packages/ArangoDB` path or Gate-0 "nothing exists yet" wording was found in the governance sources listed at the top of this page.
