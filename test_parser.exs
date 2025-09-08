alias Oli.TorusDoc.PageParser

yaml = """
type: page
id: test-page
title: Test Page
blocks:
  - type: activity
    activity:
      type: mcq
      stem_md: "What is 2+2?"
      choices:
        - id: "a"
          body_md: "3"
          score: 0
        - id: "b"
          body_md: "4"
          score: 1
"""

case PageParser.parse(yaml) do
  {:ok, page} ->
    [activity_block] = page.blocks
    IO.inspect(activity_block, label: "Activity block", pretty: true)
    IO.inspect(activity_block.activity, label: "Activity", pretty: true)

  {:error, reason} ->
    IO.puts("Error: #{reason}")
end
