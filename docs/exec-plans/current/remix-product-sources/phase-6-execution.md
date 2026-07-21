# Phase 6 Execution Record

Work item: `docs/exec-plans/current/remix-product-sources`
Phase: `6 - Final Verification and Release Readiness`

## Scope from plan.md
- Final verification and release-readiness work for remix product/template sources.
- Follow-up implementation for admin authors customizing real course sections: admin-author Remix on `type: :enrollable` sections must include product/template sources.
- Corrective follow-up for hidden-instructor admin delivery access: section-scoped hidden instructor sessions on `type: :enrollable` sections must see active-community project and product/template sources during Remix source discovery.
- Corrective follow-up for mixed admin-author and hidden-instructor sessions: real course section Remix must prefer the section-scoped hidden instructor match before the admin-author match.

## Implementation Blocks
- [x] Core behavior changes
  - Added `Oli.Delivery.Remix.init_admin_instructor/2` for admin-authored enrollable section Remix.
  - Routed the admin/enrollable LiveView branch through the new initializer.
  - Added a section-scoped hidden-instructor user initializer branch for enrollable section Remix that augments normal user-visible sources with active-community project and product/template sources.
  - Updated section mount precedence so hidden instructor users win over admin authors for real course section Remix.
  - Hardened product-source page listing and selection so descendants of hidden product containers are excluded by the `SectionResourceDepot`-backed visible hierarchy.
- [x] Data or interface changes
  - No database migration or persisted state change.
  - Product/template source discovery for this path uses active blueprint sections and existing pinned publication resolution.
  - Hidden-instructor source expansion reads existing active-community `communities_visibilities.project_id` and `communities_visibilities.section_id` rows and does not create community memberships.
- [x] Access-control or safety checks
  - Scoped the initializer to `Section.type == :enrollable`.
  - Required `Accounts.at_least_content_admin?/1`.
  - Preserved generic author initialization and product-template editing behavior.
  - Scoped hidden-instructor community expansion to `User.hidden == true` users that are instructors in the target section.
  - Preserved admin-author precedence for non-hidden users and product/template section Remix.
- [x] Observability or operational updates when needed
  - No new telemetry was required; existing source-selection and add-materials telemetry paths apply after a product/template source is selected.

## Test Blocks
- [x] Tests added or updated
  - Added domain tests for admin-author product/template source availability, generic author initializer isolation, and blueprint-section rejection.
  - Added domain coverage for section-scoped hidden instructor visibility of active-community project and product/template sources without exposing deleted-community projects, unassociated products, deleted-community products, or product sources to random hidden users.
  - Added product-source resolution coverage for visible descendants beneath hidden product containers.
  - Added LiveView coverage for an admin author opening Add Materials on an enrollable section and selecting a product/template source.
  - Added LiveView coverage for a hidden instructor session opening Add Materials on an enrollable section and selecting an active-community product/template source.
  - Strengthened hidden-instructor LiveView coverage to prove unrelated active templates are excluded, which catches accidental fallback to the admin-author source policy.
- [x] Required verification commands run
  - `mix test test/oli/delivery/remix/init_test.exs test/oli_web/live/remix_section_test.exs`
  - `mix test test/oli/delivery/remix test/oli_web/live/remix_section_test.exs test/scenarios/delivery/remix_product_sources_test.exs`
  - `mix format --check-formatted`
  - `git diff --check`
  - `python3 <skills_root>/validate/scripts/validate_work_item.py docs/exec-plans/current/remix-product-sources --check all`
- [x] Results captured
  - Focused domain and LiveView suites passed.
  - Broader targeted Remix domain, Remix LiveView, and scenario suite passed.
  - Format, whitespace, and work-item validation passed.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - Updated `fdd.md` and `plan.md` to document the admin-author course-section source policy and the Remix-scoped hidden-instructor community source policy.
- [x] Open questions added to docs when needed
  - No new open questions.

## Review Loop
- Round 1 findings:
  - Local security/performance/Elixir review found one hardening opportunity: return only required product fields from the admin product-source query and use repo-preferred explicit branch style.
- Round 1 fixes:
  - Updated the product query projection to `[:id, :title, :slug]`.
  - Replaced the admin authorization `if` branch with `case`.
- Round 2 findings:
  - Security review flagged the first hidden-instructor expansion as too broad because a random hidden user could invoke it without proving it was the section-scoped hidden instructor.
- Round 2 fixes:
  - Added a `Sections.is_instructor?/2` guard before hidden-instructor active-community product/template expansion.
  - Added regression coverage proving random hidden users do not get community product/template expansion.
- Round 3 findings:
  - Runtime validation showed mixed admin-author and hidden-instructor sessions were still matching the admin-author path first for real course section Remix.
- Round 3 fixes:
  - Updated mount precedence to prefer a valid hidden instructor before admin-author matching for real course sections.
- Round 4 findings:
  - Runtime validation showed hidden instructors could see active-community templates but not active-community projects.
- Round 4 fixes:
  - Added active-community project publication expansion to the section-scoped hidden-instructor Remix source policy.
  - Added regression coverage proving hidden instructors see community project sources as well as community product/template sources.

## Done Definition
- [x] Phase follow-up tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
