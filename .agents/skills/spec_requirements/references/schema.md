# Requirements Schema

`requirements.yml` is authoritative and uses:

- `version`: required integer (`1`)
- `feature`: required non-empty string
- `generated_from`: required non-empty string
- `requirements`: required non-empty list of FR records

FR record:

- `id`: required, unique, `^FR-\d{3}$`
- `title`: required non-empty string
- `status`: one of `proposed|verified_fdd|verified_plan|verified`
- `acceptance_criteria`: required non-empty list of AC records
- `proofs`: forbidden at FR level

AC record:

- `id`: required, unique, `^AC-\d{3}$`
- `title`: required non-empty string
- `status`: one of `proposed|verified_fdd|verified_plan|verified`
- `verification_method`: optional, one of `automated|manual|hybrid`, default `automated`
- `proofs`: required list (can be empty only when status is `proposed`)

Proof record:

- `type`: one of `fdd|plan|test|code|manual`
- `ref`: non-empty string reference to `path[#anchor]`, `path:line`, or `path::"descriptor"`

Status order:

`proposed < verified_fdd < verified_plan < verified`

FR status is derived as the minimum status among its ACs.
