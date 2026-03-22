# Backstage Portal Setup

## Overview

The Backstage portal is a thin interface over the backend-first IDP. It provides
Software Templates (forms) that generate the same claim YAML a developer would
write by hand or create with the `platform` CLI.

**The portal is optional.** The backend works the same regardless of which
interface submits the claim.

## Quick Start (Docker Compose)

```bash
cd portal/backstage

# Set GitHub token for PR creation
export GITHUB_TOKEN=ghp_your_token_here

# Start Backstage
docker-compose up -d

# Open in browser
open http://localhost:3000
```

## Software Templates

Six templates are available in the Backstage scaffolder:

| Template | What It Creates |
|----------|----------------|
| **Request a Database** | DatabaseInstanceClaim (PostgreSQL/MySQL) |
| **Request a Cache** | CacheInstanceClaim (Redis/Memcached) |
| **Request a Message Queue** | MessageQueueClaim (SQS/PubSub/ServiceBus) |
| **Request Object Storage** | ObjectStorageClaim (S3/GCS/Blob) |
| **Request a CDN** | CDNDistributionClaim (CloudFront/CDN/FrontDoor) |
| **Full Service Resources** | DB + cache + queue + storage in one step |

Each template:
1. Presents a form with the XRD's fields (size, region, team, etc.)
2. Generates valid claim YAML using skeleton templates
3. Opens a PR to `teams/{team}/claims/` in the platform repo
4. ArgoCD picks up the PR once merged

## Catalog

The Backstage catalog shows:
- **12 team groups** with their descriptions
- **Platform system** with the API definition (7 XRD types)

## Three Interfaces, One Backend

The same claim can be created three ways:

```
Git:        vim teams/checkout/claims/checkout-db.yaml && git commit && git push
CLI:        platform create database --team checkout --size small --submit
Backstage:  Fill form → click Create → PR opens → merge → deployed
```

All three produce identical YAML. The backend doesn't know or care which
interface created the claim.
