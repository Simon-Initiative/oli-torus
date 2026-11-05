Media upload fixtures for Playwright live in this folder (`media_files/`). No .env files are required by the automation suite.

Files in `media_files/` can also be served to the browser at `/test/support/<filename>` when Playwright scenarios are enabled. Add the file name and its content type to the allowlist in `lib/oli_web/controllers/playwright_support_asset_controller.ex` to expose a new fixture.
