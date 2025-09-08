# Demo script showing how to use the clone directive
# Run with: mix run lib/oli/torus_doc/clone_demo.exs

alias Oli.TorusDoc

# Example 1: Clone directive YAML document
clone_yaml = """
type: project_directive
directive: clone
from: source-project-slug
to: new-cloned-project
"""

# This would clone an entire project (requires valid project and author)
IO.puts("Clone Directive Example:")
IO.puts(clone_yaml)
IO.puts("\nTo execute this directive, you would call:")
IO.puts("TorusDoc.process(yaml, %{author: author})")
IO.puts("\nThis will:")
IO.puts("1. Clone the entire 'source-project-slug' project")
IO.puts("2. Create a new project with all resources, publications, media, etc.")
IO.puts("3. Add the author as a collaborator on the new project")
IO.puts("4. Return the cloned project details")

# Example 2: Regular page document (for comparison)
page_yaml = """
type: page
id: my-page
title: My Page
blocks:
  - type: prose
    body_md: |
      # This is a regular page
      Not a clone directive - just normal page content.
"""

IO.puts("\n\nRegular Page Example (for comparison):")
IO.puts(page_yaml)
IO.puts("\nThis processes as a normal page, not a project operation.")

# The key difference:
IO.puts("\n\nKey Difference:")
IO.puts("- 'type: project_directive' → Project-level operation (like cloning)")
IO.puts("- 'type: page' → Page content processing")
IO.puts("\nThe clone directive operates at the PROJECT level, not within page content!")
