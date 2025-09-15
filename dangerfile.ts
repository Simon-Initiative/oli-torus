import { danger, fail, warn, markdown, schedule } from "danger"
import * as fs from "node:fs"
import * as yaml from "js-yaml"
import * as micromatch from "micromatch"

// 1) Basic size guard
const modified = (danger.github?.pr?.additions || 0) + (danger.github?.pr?.deletions || 0)
console.log(`[danger] PR size additions+deletions: ${modified}`)
if (modified > 800) {
  warn(`PR is large (${modified} LOC changed). Consider splitting.`)
}

// 2) Require tests if Elixir code changed
const modifiedFiles = danger.git.modified_files || []
const createdFiles = danger.git.created_files || []
const allChanged = [...modifiedFiles, ...createdFiles]
console.log(`[danger] Changed files count: ${allChanged.length}`)
const exChanges = allChanged.filter((f) => f.endsWith(".ex"))
const hasTests = allChanged.some((f) => f.startsWith("test/") || f.includes("_test.exs"))
const missingTests = exChanges.length && !hasTests
if (missingTests) {
  warn("Elixir code changed but no tests were modified or added.")
}

// Risk labeler from repo rules
try {
  console.log(`[danger] Loading .ci/RISK_RULES.yaml ...`)
  const raw = fs.readFileSync(".ci/RISK_RULES.yaml", "utf8")
  const cfg: any = yaml.load(raw)
  let score = 0

  // Size rule
  const size = cfg.size?.big_diff_loc
  if (size) {
    const thr = typeof size.threshold === "number" ? size.threshold : 400
    const w = typeof size.weight === "number" ? size.weight : 3
    if (modified > thr) {
      score += w
      console.log(`[danger] Size rule matched (>${thr}) adding ${w}`)
    }
  }

  // If Elixir changed without tests, automatically escalate risk to HIGH
  if (missingTests) {
    const highThr = cfg.thresholds?.high ?? 9
    // Ensure score meets/exceeds HIGH threshold
    score = Math.max(score, highThr + 1)
    console.log("[danger] Missing tests for Elixir changes → forcing risk/high")
  }

  // Path rules: add weight if any changed file matches any glob
  const rules = Array.isArray(cfg.rules) ? cfg.rules : []
  for (const r of rules) {
    const globs: string[] = Array.isArray(r?.globs) ? r.globs : []
    if (!globs.length) continue
    const hit = micromatch(allChanged, globs)
    if (hit.length > 0) {
      const w = (typeof r.weight === "number" ? r.weight : 0)
      score += w
      console.log(`[danger] Rule '${r.key || "(unnamed)"}' matched ${hit.length} file(s); +${w}`)
    }
  }

  // Multipliers
  const mult = cfg.multipliers || {}
  const applyMult = (m?: any) => {
    if (!m) return
    const thr = typeof m.threshold === "number" ? m.threshold : undefined
    const factor = typeof m.factor === "number" ? m.factor : 1
    if (thr && modified > thr) score = Math.round(score * factor)
  }
  applyMult(mult.very_large_pr)
  applyMult(mult.huge_pr)

  const high = cfg.thresholds?.high ?? 9
  const low = cfg.thresholds?.low ?? 3
  const tier = score >= high ? "high" : score > low ? "medium" : "low"
  const label = `risk/${tier}`
  console.log(`[danger] Risk score=${score}, tier=${tier}, label='${label}'`)

  schedule(async () => {
    const { owner, repo, number } = danger.github.thisPR
    const colors: Record<string, string> = { low: "66c2a5", medium: "ffd92f", high: "fc8d62" }
    const color = colors[tier] || "cccccc"
    try {
      // Ensure label exists (create if missing)
      try {
        console.log(`[danger] Checking for existing label '${label}'`)
        await danger.github.api.issues.getLabel({ owner, repo, name: label })
      } catch {
        try {
          console.log(`[danger] Creating label '${label}' with color ${color}`)
          await danger.github.api.issues.createLabel({ owner, repo, name: label, color })
        } catch (e) {
          const msg = (e as any)?.message || String(e)
          console.log(`[danger] WARN could not create label '${label}': ${msg}`)
          warn(`Could not create label '${label}': ${msg}`)
        }
      }
      // Add label
      console.log(`[danger] Adding label '${label}' to PR #${number}`)
      await danger.github.api.issues.addLabels({ owner, repo, issue_number: number, labels: [label] })
      console.log(`[danger] Label '${label}' added successfully`)
    } catch (e) {
      const msg = (e as any)?.message || String(e)
      console.log(`[danger] WARN could not add risk label '${label}': ${msg}`)
      warn(`Could not add risk label '${label}': ${msg}`)
    }
  })

  markdown(`**Risk score:** ${score} → \`${label}\``)
} catch (e) {
  const msg = (e as any)?.message || String(e)
  console.log(`[danger] RISK_RULES not loaded or parse failed: ${msg}`)
  markdown(`_Note: risk rules not loaded — ${msg}_`)
}

// 5) Aggregate AI reviewer (optional): if ai/verdict.json exists, summarize
try {
  if (fs.existsSync("ai/verdict.json")) {
    const v = JSON.parse(fs.readFileSync("ai/verdict.json", "utf8"))
    markdown(["### AI Review Summary (from ai/verdict.json)", "", v.markdown || "(no summary)"].join("\n"))
  }
} catch {
  // ignore
}
