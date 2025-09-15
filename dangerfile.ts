import { danger, fail, warn, markdown, schedule } from "danger"
import fs from "node:fs"
import yaml from "js-yaml"
import micromatch from "micromatch"

// 1) Basic size guard
const modified = (danger.github?.pr?.additions || 0) + (danger.github?.pr?.deletions || 0)
if (modified > 800) {
  warn(`PR is large (${modified} LOC changed). Consider splitting.`)
}

// 2) Require tests if Elixir code changed
const modifiedFiles = danger.git.modified_files || []
const createdFiles = danger.git.created_files || []
const allChanged = [...modifiedFiles, ...createdFiles]
const exChanges = allChanged.filter((f) => f.endsWith(".ex"))
const hasTests = allChanged.some((f) => f.startsWith("test/") || f.includes("_test.exs"))
if (exChanges.length && !hasTests) {
  fail("Changes to Elixir code but no tests were modified or added.")
}

// Risk labeler from repo rules
try {
  const raw = fs.readFileSync(".ci/RISK_RULES.yaml", "utf8")
  const cfg: any = yaml.load(raw)
  let score = 0

  // Size rule
  const size = cfg.size?.big_diff_loc
  if (size) {
    const thr = typeof size.threshold === "number" ? size.threshold : 400
    const w = typeof size.weight === "number" ? size.weight : 3
    if (modified > thr) score += w
  }

  // Path rules: add weight if any changed file matches any glob
  const rules = Array.isArray(cfg.rules) ? cfg.rules : []
  for (const r of rules) {
    const globs: string[] = Array.isArray(r?.globs) ? r.globs : []
    if (!globs.length) continue
    if (micromatch(allChanged, globs).length > 0) {
      score += (typeof r.weight === "number" ? r.weight : 0)
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

  schedule(async () => {
    const { owner, repo, number } = danger.github.thisPR
    const colors: Record<string, string> = { low: "66c2a5", medium: "ffd92f", high: "fc8d62" }
    const color = colors[tier] || "cccccc"
    try {
      // Ensure label exists (create if missing)
      try {
        await danger.github.api.issues.getLabel({ owner, repo, name: label })
      } catch {
        try {
          await danger.github.api.issues.createLabel({ owner, repo, name: label, color })
        } catch (e) {
          // If creation fails (permissions), continue; we'll still try to add
          warn(`Could not create label '${label}': ${String(e)}`)
        }
      }
      // Add label
      await danger.github.api.issues.addLabels({ owner, repo, issue_number: number, labels: [label] })
    } catch (e) {
      warn(`Could not add risk label '${label}': ${String(e)}`)
    }
  })

  markdown(`**Risk score:** ${score} → \`${label}\``)
} catch {
  // Optional – rules file absent
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
