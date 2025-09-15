Checklist for Elixir reviewer

- LiveView boundaries respected (no DB calls in LV; context used)
- Ecto: no N+1; queries batched; indexes where needed
- AuthZ/AuthN: plugs, LTI roles, tenant scoping enforced
- Tests: unit + LiveView/integration added or updated
- Performance: avoid loops with DB calls; use Depot/cache where applicable
- Observability: errors handled, logs reasonable (no secrets)

