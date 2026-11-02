Media upload fixtures for Playwright live in this folder (`media_files/`). No .env files are required by the automation suite.

Public support fixtures are packaged in `priv/playwright/` and linked from `media_files/` for local uploads. When Playwright scenarios are enabled, allowlisted fixtures are served at `/test/support/<filename>`. To expose a new fixture, place it in `priv/playwright/`, link it from `media_files/`, and map its URL filename to the packaged filename and content type in `lib/oli_web/controllers/playwright_support_asset_controller.ex`.
