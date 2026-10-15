// Exercise the workflow's inline code directly; no parallel implementation of CI logic.
const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const vm = require("node:vm");
const { test } = require("node:test");

const workflow = JSON.parse(
  execFileSync("python3", [
    "-c",
    'import json,yaml; print(json.dumps(yaml.safe_load(open(".github/workflows/nightly-playwright.yml"))))',
  ])
);
const jobs = workflow.jobs;
const deploy = jobs["deploy-plasma"];
const step = (id) => deploy.steps.find((s) => s.id === id);
const readyCode = step("ready")
  .run.split("node <<'JS'\n")[1]
  .replace(/\nJS\n?$/, "");
const sha = "a".repeat(40);
const version = "0.35.0";
const matching = { status: "ready", version, sha };

async function readiness(observations, identity = {}, overrides = {}) {
  let now = 0;
  let requests = 0;
  const files = {};
  const timers = [];
  const sleeps = [];
  const inputs = [];
  const process = {
    env: {
      APP_VERSION: version,
      SOURCE_SHA: sha,
      RUNNER_TEMP: "/tmp",
      GITHUB_STEP_SUMMARY: "/summary",
      ...identity,
    },
    exitCode: 0,
  };
  const context = {
    require: (name) =>
      name === "node:fs"
        ? {
            writeFileSync: (p, value) => {
              files[p] = value;
            },
            appendFileSync: (p, value) => {
              files[p] = (files[p] || "") + value;
            },
          }
        : { performance: { now: () => now } },
    process,
    Buffer,
    AbortController,
    console,
    setTimeout: (fn, ms) => {
      // Abort timers are recorded; sleep advances the fake monotonic clock.
      if (fn.toString().includes("controller.abort()")) timers.push(ms);
      else {
        sleeps.push(ms);
        now += ms;
        fn();
      }
      return 1;
    },
    clearTimeout: () => {},
    fetch: async (url, options) => {
      inputs.push({ url, options });
      const observation =
        observations[Math.min(requests++, observations.length - 1)];
      now += observation.elapsed || 0;
      if (observation.error) throw new Error("private network error");
      let sent = false;
      const body =
        observation.raw ?? JSON.stringify(observation.data ?? matching);
      return {
        status: observation.status ?? 200,
        body: {
          cancel: async () => {},
          getReader: () => ({
            read: async () =>
              sent
                ? { done: true }
                : ((sent = true), { value: Buffer.from(body) }),
            cancel: async () => {},
          }),
        },
      };
    },
  };
  await vm.runInNewContext(readyCode, { ...context, ...overrides });
  return { process, files, timers, sleeps, inputs, now };
}

test("matching public identity succeeds using HTTPS without credentials or redirects", async () => {
  const result = await readiness([{}]);
  assert.equal(result.process.exitCode, 0);
  assert.match(result.files["/summary"], /Observed expected version\/commit/);
  assert.equal(result.inputs.length, 1);
  const { url, options } = result.inputs[0];
  assert.equal(url, "https://nightly-playwright.plasma.oli.cmu.edu/readyz");
  assert.equal(options.redirect, "manual");
  assert.equal(options.credentials, "omit");
  assert.deepEqual(Object.keys(options.headers).sort(), [
    "Cache-Control",
    "Pragma",
  ]);
  assert.ok(options.signal instanceof AbortSignal);
  assert.ok(!readyCode.includes("NODE_TLS_REJECT_UNAUTHORIZED"));
});

test("old identity, HTTP errors, redirects and network/TLS errors retry before success", async () => {
  const result = await readiness([
    { data: { ...matching, sha: "b".repeat(40) } },
    { data: { ...matching, version: "0.34.0" } },
    { status: 503 },
    { status: 302 },
    { error: true },
    {},
  ]);
  assert.equal(result.inputs.length, 6);
  assert.equal(result.process.exitCode, 0);
  assert.equal(result.now, 50000);
});

test("malformed, non-string, missing, not-ready and oversized bodies cannot satisfy readiness", async () => {
  for (const observation of [
    { raw: "<html>private login content</html>" },
    { data: { ...matching, status: "not_ready" } },
    { data: { ...matching, version: 35 } },
    { data: { status: "ready", version } },
    { data: null, raw: "null" },
    { data: [matching] },
    { raw: "x".repeat(4097) },
  ]) {
    const result = await readiness([observation]);
    assert.equal(result.process.exitCode, 1);
    assert.equal(result.now, 1200000);
    assert.match(result.files["/summary"], /browser execution is skipped/);
    assert.ok(!result.files["/summary"].includes("private login content"));
    assert.ok(result.files["/summary"].length < 700);
  }
});

test("request and sleep budgets clamp to remaining deadline; late success fails", async () => {
  const result = await readiness([{ status: 503, elapsed: 1195000 }]);
  assert.deepEqual(result.timers, [10000]);
  assert.deepEqual(result.sleeps, [5000]);
  assert.equal(result.now, 1200000);
  const nearDeadline = await readiness([{ status: 503, elapsed: 1189999 }, {}]);
  assert.deepEqual(nearDeadline.timers, [10000, 1]);
  const late = await readiness([{ elapsed: 1200001 }]);
  assert.equal(late.process.exitCode, 1);
});

test("a stalled response stream is aborted and polling recovers", async () => {
  let requests = 0;
  let aborted = false;
  const result = await readiness(
    [{}],
    {},
    {
      setTimeout: (fn, ms) => setTimeout(fn, Math.min(ms, 20)),
      clearTimeout,
      fetch: async (url, options) => {
        if (requests++ > 0) return new Response(JSON.stringify(matching));
        return new Response(
          new ReadableStream({
            start(controller) {
              options.signal.addEventListener("abort", () => {
                aborted = true;
                controller.error(new DOMException("Aborted", "AbortError"));
              });
            },
          })
        );
      },
    }
  );
  assert.ok(aborted);
  assert.equal(requests, 2);
  assert.equal(result.process.exitCode, 0);
});

test("invalid expected identities fail before any request", async () => {
  await assert.rejects(
    readiness([{}], { SOURCE_SHA: "short-sha" }),
    /Invalid expected/
  );
  await assert.rejects(
    readiness([{}], { APP_VERSION: "https://user:secret@other.test" }),
    /Invalid expected/
  );
});

async function createPR({
  uncertain = false,
  matches = 1,
  verified = true,
} = {}) {
  const calls = [];
  const output = {};
  const github = {
    rest: {
      git: {
        createRef: async (args) => {
          calls.push(["ref", args]);
        },
        getCommit: async () => ({ data: { verification: { verified } } }),
      },
      pulls: {
        create: async (args) => {
          calls.push(["create", args]);
          if (uncertain) throw new Error("lost response");
          return { data: { number: 17 } };
        },
        list: async (args) => {
          calls.push(["recover", args]);
          return {
            data: Array.from({ length: matches }, () => ({ number: 17 })),
          };
        },
      },
    },
    graphql: async (query, args) => {
      calls.push(["commit", args]);
      return { createCommitOnBranch: { commit: { oid: sha } } };
    },
  };
  const code = `(async () => {${step("pr").with.script}\n})()`;
  await vm.runInNewContext(code, {
    require: () => ({ readFileSync: () => Buffer.from("validated record") }),
    github,
    core: {
      setOutput: (key, value) => {
        output[key] = value;
      },
    },
    process: {
      env: {
        GITOPS_REPO: "Simon-Initiative/oli-torus-gitops",
        RUN_KEY: "123-2",
        BASE_SHA: sha,
        SOURCE_SHA: sha,
        IMAGE_TAG: `sha-${sha}-playwright-123-2`,
      },
    },
  });
  return { calls, output };
}

test("signed PR submission uses the validated base and exactly one record", async () => {
  const { calls, output } = await createPR();
  assert.equal(output.number, 17);
  assert.equal(calls[0][1].ref, "refs/heads/nightly-playwright/123-2");
  const input = calls[1][1].input;
  assert.equal(input.expectedHeadOid, sha);
  assert.equal(input.fileChanges.additions.length, 1);
  assert.equal(
    input.fileChanges.additions[0].path,
    "deployments/nightly-playwright.yml"
  );
  assert.equal(calls[2][1].base, "master");
});

test("uncertain creation recovers only its exact branch; ambiguity and unsigned commits fail", async () => {
  const { calls, output } = await createPR({ uncertain: true });
  assert.equal(output.number, 17);
  assert.equal(
    calls.at(-1)[1].head,
    "Simon-Initiative:nightly-playwright/123-2"
  );
  await assert.rejects(
    createPR({ uncertain: true, matches: 0 }),
    /Could not recover/
  );
  await assert.rejects(
    createPR({ uncertain: true, matches: 2 }),
    /Could not recover/
  );
  await assert.rejects(
    createPR({ verified: false }),
    /signature was not verified/
  );
});

test("workflow failure gates, finalization and credential boundaries are preserved", () => {
  assert.equal(deploy.needs, "build-playwright");
  assert.deepEqual(jobs["nightly-playwright"].needs, [
    "build-playwright",
    "deploy-plasma",
  ]);
  for (const jobName of [
    "deploy-plasma",
    "nightly-playwright",
    "nightly-scenarios",
  ]) {
    assert.match(jobs[jobName].if, /!inputs.publish_only/);
    assert.ok(!jobs[jobName].if.includes("always()"));
  }
  assert.equal(jobs["nightly-scenarios"].needs, undefined);
  const order = deploy.steps.filter((s) => s.id).map((s) => s.id);
  assert.ok(order.indexOf("record") < order.indexOf("pr"));
  assert.ok(order.indexOf("merge") < order.indexOf("ready"));
  for (const id of ["record", "pr", "merge", "ready"]) {
    assert.equal(step(id)["continue-on-error"], undefined);
    assert.equal(step(id).if, undefined);
  }
  const settle = deploy.steps.find((s) => s.name.startsWith("Settle"));
  assert.match(settle.if, /always\(\)/);
  assert.ok(!settle.if.includes("steps.pr.outcome"));
  assert.match(settle.run, /--head "nightly-playwright\/\$RUN_KEY"/);
  assert.match(settle.run, /nightly_deployment_pr.py settle/);
  assert.equal(deploy.environment, "nightly-deploy");
  for (const name of ["build-playwright", "nightly-playwright"]) {
    assert.ok(!JSON.stringify(jobs[name]).includes("GITOPS_APP"));
    assert.equal(jobs[name].environment, "nightly-ui");
  }
  assert.equal(workflow.concurrency.group, "nightly-playwright-plasma");
  assert.equal(workflow.concurrency["cancel-in-progress"], false);
  assert.equal(jobs["summarize-nightly"].if, "always()");
  for (const job of Object.values(jobs))
    assert.equal(job["continue-on-error"], undefined);
});

test("browser uses source SHA, configured reporters, failure status and retained artifacts", () => {
  const browser = jobs["nightly-playwright"];
  const tests = browser.steps.find((s) => s.id === "tests");
  assert.equal(
    tests.run,
    "npx playwright test --config playwright.nightly.config.ts --grep @nightly"
  );
  assert.equal(tests["continue-on-error"], undefined);
  assert.match(
    browser.steps[0].with.ref,
    /needs.build-playwright.outputs.source-sha/
  );
  const uploads = browser.steps.filter((s) =>
    s.uses?.startsWith("actions/upload-artifact")
  );
  assert.equal(uploads.length, 2);
  for (const upload of uploads) {
    assert.equal(upload.if, "always()");
    assert.equal(upload.with["retention-days"], 14);
  }
  for (const input of [
    "CANVAS_BASE_URL",
    "CANVAS_ACCOUNT_ID",
    "CANVAS_INSTRUCTOR_USER_ID",
    "CANVAS_LTI_TOOL_NAME",
    "CANVAS_TOOL_LAUNCH_URL",
    "CANVAS_API_TOKEN",
    "MOODLE_BASE_URL",
    "PLAYWRIGHT_PARAMETER_CONFIG_URL",
  ])
    assert.ok(browser.env[input]);
  assert.match(
    jobs["build-playwright"].steps[0].with.ref,
    /github.sha.*refs\/heads\/master/
  );
});
