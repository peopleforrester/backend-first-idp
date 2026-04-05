# Interface Layer Plan — CLI + Backstage Portal

## Thesis

The backend-first IDP is complete. Now we add two thin interface layers to
prove the thesis: **the portal is optional because the backend does the work.**
Both the CLI and Backstage are skins over the same backend — they generate
claim YAML, validate against Kyverno, and commit to git. The platform API
(XRDs + compositions + policies) doesn't change.

```
                    ┌─────────────────────┐
                    │   Interface Layer   │
                    │   (optional)        │
                    ├─────────┬───────────┤
                    │  CLI    │ Backstage │
                    │  (Go)   │ (CNCF)    │
                    └────┬────┴─────┬─────┘
                         │          │
                         ▼          ▼
                    ┌─────────────────────┐
                    │   Git (claims/)     │  ← same git repo
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   Backend           │
                    │   (unchanged)       │
                    │   ArgoCD → Kyverno  │
                    │   → Crossplane      │
                    └─────────────────────┘
```

Both interfaces produce the exact same YAML that a developer would write by hand.
The backend doesn't know or care which interface submitted the claim.

---

## Part 1: Platform CLI (`platform`)

### What It Does

A Go CLI that wraps the golden path into commands:

```bash
# Create a database claim interactively
platform create database --team checkout --size small --region eu-west-1

# Create from a preset (the full-service golden path)
platform create service --team catalog --preset full

# Validate a claim against Kyverno policies (local, no cluster needed)
platform validate golden-path/examples/claim-database-WILL-FAIL.yaml

# List available resource types (reads XRDs)
platform list types

# List team claims
platform list claims --team checkout

# Dry-run: generate YAML without writing
platform create database --team checkout --size small --dry-run

# Submit: generate + validate + commit + push
platform create database --team checkout --size small --submit
```

### Why Go

- Kubernetes ecosystem language — attendees expect it
- Single binary, no runtime dependencies
- cobra/viper for CLI framework (standard in K8s tooling)
- Can embed Kyverno validation logic directly

### Architecture

```
cli/
├── cmd/
│   ├── root.go              # Root command, global flags
│   ├── create.go            # 'platform create' subcommand
│   ├── create_database.go   # 'platform create database'
│   ├── create_cache.go      # 'platform create cache'
│   ├── create_queue.go      # 'platform create queue'
│   ├── create_storage.go    # 'platform create storage'
│   ├── create_cdn.go        # 'platform create cdn'
│   ├── create_namespace.go  # 'platform create namespace'
│   ├── create_service.go    # 'platform create service' (full preset)
│   ├── validate.go          # 'platform validate' (run kyverno locally)
│   └── list.go              # 'platform list types|claims'
├── pkg/
│   ├── claim/
│   │   ├── generator.go     # Generates claim YAML from flags
│   │   ├── templates.go     # Embedded YAML templates per resource type
│   │   └── validator.go     # Kyverno CLI wrapper for local validation
│   ├── git/
│   │   └── submit.go        # Git add + commit + push to team branch
│   └── xrd/
│       └── reader.go        # Reads XRD files to discover available types/fields
├── main.go
├── go.mod
├── go.sum
├── Makefile                  # Build targets
└── tests/
    ├── create_test.go        # Unit tests for claim generation
    ├── validate_test.go      # Integration tests with kyverno
    └── testdata/             # Expected YAML outputs
```

### Key Design Decisions

1. **Templates, not code generation** — Each resource type has an embedded Go
   template that mirrors the golden-path YAML. The CLI fills in the blanks.
   This means the CLI output is always identical to hand-written claims.

2. **Kyverno validation built in** — `platform validate` shells out to `kyverno apply`
   against the repo's policies. No cluster needed. Developers get the same
   policy feedback locally that they'd get from admission control.

3. **Git-native submit** — `--submit` writes the claim to `teams/{team}/claims/`,
   commits with a conventional message, and pushes. ArgoCD picks it up.

4. **XRD-aware** — `platform list types` reads the XRD files to show available
   resource types, fields, enums, and defaults. The CLI never goes stale
   relative to the platform API because it reads the source of truth.

### TDD Phases

**Phase A: Scaffolding**
- Go module, cobra CLI skeleton, root/create/validate/list commands
- Makefile with build/test/lint targets
- No functionality yet, just the command tree

**Phase B: Claim generation**
- `platform create database` generates valid claim YAML
- Templates for all 7 resource types
- `--dry-run` prints YAML to stdout
- Unit tests: generated YAML matches expected output

**Phase C: Validation**
- `platform validate <file>` runs kyverno apply against repo policies
- Integration test: validate good claim passes, bad claim fails

**Phase D: List and discovery**
- `platform list types` reads XRDs, shows resource types + fields
- `platform list claims --team checkout` reads teams/ directory

**Phase E: Submit**
- `--submit` flag: write to teams/{team}/claims/, git commit, push
- Requires git repo context (errors if not in repo)

**Phase F: Full service preset**
- `platform create service --team catalog --preset full` generates
  DB + cache + queue + storage in one command

---

## Part 2: Backstage Portal

### Why Backstage

- CNCF Incubating — the right choice at a CNCF conference
- The most widely adopted developer portal in the ecosystem
- Backstage Software Templates are the "portal golden path" equivalent
- Proves the thesis: Backstage is a thin form over git, not the system

### What It Does

A Backstage instance with:
1. **Software Templates** — forms that generate claim YAML and open PRs
2. **Catalog integration** — shows provisioned resources per team
3. **TechDocs** — serves the repo's docs/ directory
4. **Kubernetes plugin** — shows claim status from the cluster

### Architecture

```
portal/
├── backstage/
│   ├── app-config.yaml           # Backstage configuration
│   ├── app-config.production.yaml
│   ├── catalog-info.yaml         # Root catalog entity
│   ├── packages/
│   │   ├── app/                  # Frontend (React)
│   │   │   ├── src/
│   │   │   └── package.json
│   │   └── backend/              # Backend (Node.js)
│   │       ├── src/
│   │       └── package.json
│   ├── templates/                # Software Templates
│   │   ├── database-claim/
│   │   │   ├── template.yaml     # Template definition
│   │   │   └── skeleton/
│   │   │       └── claim.yaml    # Claim YAML with ${{ parameters }}
│   │   ├── cache-claim/
│   │   │   ├── template.yaml
│   │   │   └── skeleton/
│   │   │       └── claim.yaml
│   │   ├── queue-claim/
│   │   │   ├── template.yaml
│   │   │   └── skeleton/
│   │   │       └── claim.yaml
│   │   ├── storage-claim/
│   │   │   ├── template.yaml
│   │   │   └── skeleton/
│   │   │       └── claim.yaml
│   │   ├── full-service/
│   │   │   ├── template.yaml
│   │   │   └── skeleton/
│   │   │       ├── database.yaml
│   │   │       ├── cache.yaml
│   │   │       ├── queue.yaml
│   │   │       └── storage.yaml
│   │   └── all-templates.yaml    # Template catalog locations
│   ├── entities/                 # Catalog entities per team
│   │   ├── checkout.yaml
│   │   ├── payments.yaml
│   │   └── ... (12 teams)
│   ├── plugins/                  # Custom plugins (if needed)
│   ├── Dockerfile
│   ├── docker-compose.yaml       # Local dev setup
│   ├── package.json
│   └── yarn.lock
└── docs/
    └── backstage-setup.md        # How to run the portal
```

### Software Template Example (database-claim)

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: database-claim
  title: Request a Database
  description: Provision a managed database through the platform API
  tags:
    - platform
    - database
    - crossplane
spec:
  owner: platform-team
  type: resource-claim
  parameters:
    - title: Database Configuration
      required:
        - team
        - size
        - region
      properties:
        team:
          title: Team
          type: string
          enum:
            - checkout
            - payments
            - analytics
            - platform
            - identity
            - catalog
            - shipping
            - notifications
            - inventory
            - search
            - billing
            - marketing
        size:
          title: Instance Size
          type: string
          enum:
            - small
            - medium
            - large
          default: small
        region:
          title: Region
          type: string
          enum:
            - eu-west-1
            - eu-central-1
            - us-east-1
            - us-west-2
          default: eu-west-1
        engine:
          title: Engine
          type: string
          enum:
            - postgres
            - mysql
          default: postgres
        highAvailability:
          title: High Availability
          type: boolean
          default: false
        backupRetentionDays:
          title: Backup Retention (days)
          type: number
          default: 7

  steps:
    - id: generate
      name: Generate Claim YAML
      action: fetch:template
      input:
        url: ./skeleton
        values:
          team: ${{ parameters.team }}
          size: ${{ parameters.size }}
          region: ${{ parameters.region }}
          engine: ${{ parameters.engine }}
          highAvailability: ${{ parameters.highAvailability }}
          backupRetentionDays: ${{ parameters.backupRetentionDays }}

    - id: publish
      name: Open Pull Request
      action: publish:github:pull-request
      input:
        repoUrl: github.com?repo=backend-first-idp&owner=peopleforrester
        title: "Request database: ${{ parameters.team }}-db"
        branchName: "claim/${{ parameters.team }}-db"
        description: |
          Automated database claim from Backstage Software Template.
          Team: ${{ parameters.team }}
          Size: ${{ parameters.size }}
          Region: ${{ parameters.region }}
        targetPath: teams/${{ parameters.team }}/claims

  output:
    links:
      - title: Pull Request
        url: ${{ steps.publish.output.remoteUrl }}
```

### Key Design Decisions

1. **Templates mirror the CLI** — The Backstage template produces the exact same
   YAML as `platform create database`. Same golden path, different interface.

2. **PR-based, not direct apply** — Templates open a PR rather than committing
   directly. This keeps git history clean and enables review for non-trivial claims.

3. **Catalog from git** — Team entities are defined in `entities/` and registered
   in the Backstage catalog. The catalog shows what each team owns.

4. **No custom plugins initially** — Use stock Backstage plugins (GitHub, Kubernetes,
   TechDocs). Custom plugins only if needed for shadow metric display.

5. **Docker Compose for demo** — Local dev runs via docker-compose. No cluster
   needed to demo the portal.

### TDD Phases

**Phase G: Backstage scaffolding**
- `npx @backstage/create-app` or manual setup
- app-config.yaml pointing at the repo
- Docker Compose for local dev
- Verify it starts and serves the UI

**Phase H: Software Templates (7 resource types)**
- Template + skeleton for each resource type
- Full-service template combining DB + cache + queue + storage
- Test: template renders valid YAML matching golden path

**Phase I: Catalog entities**
- Entity YAML for each of the 12 teams
- Catalog shows teams and their owned resources
- TechDocs integration serving docs/ from the repo

**Phase J: GitHub integration**
- Templates open PRs via publish:github:pull-request
- PR targets teams/{team}/claims/ directory
- Test: template submission creates a valid PR

---

## Execution Order

```
Phase A (CLI scaffold)     Phase G (Backstage scaffold)
    │                          │
    ▼                          ▼
Phase B (claim gen)        Phase H (templates)
    │                          │
    ▼                          ▼
Phase C (validation)       Phase I (catalog)
    │                          │
    ▼                          ▼
Phase D (list/discover)    Phase J (GitHub PRs)
    │
    ▼
Phase E (git submit)
    │
    ▼
Phase F (full service)
```

CLI and Backstage are fully independent — can build in parallel.

---

## What This Proves

After both are built, the demo can show all three interfaces:

1. **Git:** Hand-write 9 lines of YAML, commit, push
2. **CLI:** `platform create database --team checkout --size small --submit`
3. **Backstage:** Fill out a form, click "Create", PR opens automatically

All three produce identical claim YAML. All three hit the same backend.
The portal is optional because the backend does the work.

This is the strongest possible version of the "portal fatigue" argument:
you can have a portal (Backstage), a CLI, or raw git — and switching
between them costs nothing because the platform API is the contract,
not the interface.
