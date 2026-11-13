// Runs inside the hosted sandbox before the agent starts. Any failure blocks startup.
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const esbuild = require("esbuild");
const { chromium } = require("playwright");

async function verify() {
  const directory = await fs.mkdtemp(
    path.join(os.tmpdir(), "torus-interactive-")
  );
  let browser;
  let server;
  try {
    const result = await esbuild.build({
      stdin: {
        contents:
          "document.querySelector('button').onclick = () => document.querySelector('output').textContent = 'Working';",
      },
      bundle: true,
      write: false,
    });
    const script = result.outputFiles[0].text;
    const html =
      '<!doctype html><button>Try it</button><output></output><script src="/app.js"></script>';
    await fs.writeFile(path.join(directory, "index.html"), html);
    await fs.writeFile(path.join(directory, "app.js"), script);
    server = http.createServer((request, response) => {
      response.setHeader(
        "Content-Type",
        request.url === "/app.js" ? "text/javascript" : "text/html"
      );
      response.end(request.url === "/app.js" ? script : html);
    });
    await new Promise((resolve, reject) => {
      server.once("error", reject);
      server.listen(0, "127.0.0.1", resolve);
    });
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    await page.getByRole("button", { name: "Try it" }).click();
    assert.equal(await page.locator("output").textContent(), "Working");
    assert.deepEqual(errors, []);
    execFileSync("python3", [
      "-c",
      [
        "import pathlib, sys, zipfile",
        "root = pathlib.Path(sys.argv[1])",
        'with zipfile.ZipFile(root / "check.zip", "w", zipfile.ZIP_DEFLATED) as bundle:',
        '    bundle.write(root / "index.html", "index.html")',
        '    bundle.write(root / "app.js", "app.js")',
        'with zipfile.ZipFile(root / "check.zip") as bundle:',
        "    assert bundle.testzip() is None",
        '    assert "index.html" in bundle.namelist()',
        '    assert "app.js" in bundle.namelist()',
      ].join("\n"),
      directory,
    ]);
    const evidence = {
      node: process.version,
      esbuild: esbuild.version,
      playwright: require("playwright/package.json").version,
      chromium: browser.version(),
      compilation: "passed",
      browser_interaction: "passed",
      zip: "passed",
    };
    await fs.writeFile(
      path.join(__dirname, "ready.json"),
      JSON.stringify(evidence, null, 2)
    );
    console.log(JSON.stringify(evidence));
  } finally {
    if (browser) await browser.close();
    if (server) await new Promise((resolve) => server.close(resolve));
    await fs.rm(directory, { recursive: true, force: true });
  }
}

verify().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
