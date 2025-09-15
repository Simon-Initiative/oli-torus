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

  schedule(async () => {
    try {
      await danger.github.api.issues.addLabels({
        ...danger.github.thisPR,
        issue_number: danger.github.thisPR.number,
        labels: [`risk/${tier}`],
      })
    } catch (e) {
      warn(`Could not add risk label: ${String(e)}`)
    }
  })

  markdown(`**Risk score:** ${score} → \`risk/${tier}\``)
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
