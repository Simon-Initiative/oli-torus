# Instructor Intelligent Dashboard - Epic Overview

Last updated: 2026-02-10

This document provides a brief overview of the Instructor Intelligent Dashboard epic (`MER-5198`) and the linked implementation stories.

## Epic Summary

The Instructor Intelligent Dashboard introduces a new instructor-facing insights surface that combines scoped analytics, actionable tiles, AI recommendations, outreach workflows, and CSV export.

## Jira Scope

- Epic: `MER-5198`
- Completed reference POC: `MER-5218`
- Linked roadmap context: `RMAP-105`

Implementation stories:
- `MER-5246` Insights > Learning Dashboard
- `MER-5248` Global Filter Navigation Learning Dashboard
- `MER-5249` Summary Tile & AI Recommendation
- `MER-5250` AI Recommendations Feedback & Regeneration
- `MER-5251` Progress Tile
- `MER-5252` Student Support Tile
- `MER-5253` Challenging Objectives Tile
- `MER-5254` Assessments Tile
- `MER-5255` View Students Profile on Hover Student Support Tile
- `MER-5256` Customizing Student Support Parameters
- `MER-5257` AI Email Capabilities & updates
- `MER-5258` Engagement & Content Containers
- `MER-5259` Expandable Tiles
- `MER-5266` Intelligent Dashboard CSV Download
- `MER-5301` [Intelligent Dashboard] Data Infra: Scope/Oracle Contracts and Registry
- `MER-5302` [Intelligent Dashboard] Data Infra: Live Data Coordinator and Request Control
- `MER-5303` [Intelligent Dashboard] Data Infra: InProcess/Revisit Cache and Tiered Limits
- `MER-5304` [Intelligent Dashboard] Data Infra: Snapshot Assembler and CSV Reuse Contract
- `MER-5310` [Intelligent Dashboard] Technical Story: Concrete Oracle Implementations
- `MER-5305` [Intelligent Dashboard] AI Infra: Recommendation Pipeline and Contracts

## Feature-Spec Required Tracks

- `data_oracles` (`MER-5301`)
  - `docs/epics/intelligent_dashboard/data_oracles/prd.md`
  - `docs/epics/intelligent_dashboard/data_oracles/fdd.md`
- `data_coordinator` (`MER-5302`)
  - `docs/epics/intelligent_dashboard/data_coordinator/prd.md`
  - `docs/epics/intelligent_dashboard/data_coordinator/fdd.md`
- `data_cache` (`MER-5303`)
  - `docs/epics/intelligent_dashboard/data_cache/prd.md`
  - `docs/epics/intelligent_dashboard/data_cache/fdd.md`
- `data_snapshot` (`MER-5304`)
  - `docs/epics/intelligent_dashboard/data_snapshot/prd.md`
  - `docs/epics/intelligent_dashboard/data_snapshot/fdd.md`
- `concrete_oracles` (`MER-5310`)
  - `docs/epics/intelligent_dashboard/concrete_oracles/README.md`

## Related Documents

- `docs/epics/intelligent_dashboard/prd.md`
- `docs/epics/intelligent_dashboard/edd.md`
- `docs/epics/intelligent_dashboard/data_oracles/prd.md`
- `docs/epics/intelligent_dashboard/data_coordinator/prd.md`
- `docs/epics/intelligent_dashboard/data_cache/prd.md`
- `docs/epics/intelligent_dashboard/data_snapshot/prd.md`
- `docs/epics/intelligent_dashboard/concrete_oracles/README.md`
- `docs/epics/intelligent_dashboard/plan.md`

## Development Lanes

1. Lane 1: Data Infrastructure and Contracts
2. Lane 2: Dashboard Shell, Scope Navigation, and Layout Controls
3. Lane 3: Core Insights Tiles and Student Support Extensions
4. Lane 4: AI Recommendation Experience
5. Lane 5: AI Email Outreach
6. Lane 6: CSV Export and Release Hardening

Full lane descriptions and dependency-ordered execution plan are documented in `docs/epics/intelligent_dashboard/plan.md`.
