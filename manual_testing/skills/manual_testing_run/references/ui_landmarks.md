# UI Landmarks

Use this file when the test case step is short and you need recognition cues to decide whether the browser is in the correct Torus surface.

## Signals You Are In Authoring
- project-focused headings or breadcrumbs
- structure or outline panels for course content
- visible editing affordances
- publish, preview, or edit actions
- editor chrome surrounding the page body

## Signals You Are In Delivery
- section-focused headings
- learner-facing course navigation
- page content presented for reading or completion
- previous/next or module navigation patterns
- absence of authoring edit controls

## Signals That The Step Is Still Loading
- visible loading spinners or skeleton states
- disabled navigation until content resolves
- editor frame present but no editable body yet

## Signals Of A Real Problem
- persistent error banners
- access denied or unauthorized messages
- blank or partially rendered shells that do not recover
- obvious route mismatch, such as landing in delivery for an authoring case

## Evidence To Capture
- page heading or breadcrumb
- URL or route fragment when useful
- the specific visible control or content region that proves success or failure
- screenshot on any failure, blocked condition, or ambiguous UI state
