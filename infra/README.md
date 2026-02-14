# GEO Platform — Infrastructure as Code (Terraform)

This repo contains Terraform code for Azure + Databricks (and later Snowflake if needed).

## Structure
- `infra/live/{dev,stage,prod}` — environment roots (state + providers + wiring)
- `infra/modules/*` — reusable modules (storage, eventhub, databricks workspace, etc.)
- `exports/azure/*` — captured `az` CLI outputs used to plan & import resources

## Quick start (dev)
1) Authenticate:
   - `az login`
   - Databricks CLI profile already configured (`~/.databrickscfg`)
2) Initialize:
   - `cd infra/live/dev`
   - `terraform init`
