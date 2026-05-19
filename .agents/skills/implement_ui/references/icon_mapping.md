# Icon Mapping

Use this reference when the brief needs to:

- confirm whether an icon already exists
- map a feature-level icon to the repo icon system
- recommend extending the icon system
- document how an icon should be sourced from Figma

## Default Source Priority

Use this order:

1. Check the Torus design-system icon catalog at `node-id=2:24`.
2. If the icon is not present there, inspect the feature-level Figma node.
3. If the feature-level node contains the icon, prefer MCP asset extraction over manual recreation.

## Repo Targets

Match the implementation surface:

- HEEx / LiveView: `OliWeb.Icons`
- React / TypeScript: `assets/src/components/misc/icons/Icons`

If the icon should become shared over time, note that it may later converge into `design_tokens/icons`, but do not bypass the current canonical modules.

## Extraction Rules

When the icon comes from Figma:

- identify the exact icon node, not just a surrounding frame
- inspect metadata or design context for that node
- if MCP returns an asset URL from `https://www.figma.com/api/mcp/asset/...`, treat the returned SVG as the source of truth
- if the selected node is a wrapper, descend to the child that actually owns the vector asset
- do not manually redraw an icon when the design-system catalog or MCP asset flow can provide the SVG

## When Manual Reconstruction Is Acceptable

Only allow manual reconstruction when all of the following are true:

- the icon is not present in the design-system catalog
- the feature-level node does not expose a usable SVG after checking the relevant vector-owning child nodes
- the limitation is called out explicitly in the brief or handoff

## Output Expectations

When icon work is in scope, the brief should state:

- which icon source was checked first
- whether an existing icon can be reused
- whether a canonical icon module must be extended
- whether any extraction constraint or ambiguity still needs approval
