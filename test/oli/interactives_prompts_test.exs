defmodule Oli.Interactives.PromptsTest do
  use ExUnit.Case, async: true

  alias Oli.Interactives.Prompts

  test "new construction is skill-directed and ends with the unmodified author request" do
    prompt = "Build a graphing lab\nUse labels with accents: température."

    {instructions, input} =
      Prompts.authoring(%{
        "prompt" => prompt,
        "skills" => [%{"id" => 19, "title" => "Interpret graphs"}]
      })

    assert instructions =~ "/workspace/.agents/skills/build-interactive/SKILL.md"
    refute instructions =~ "revise-interactive"
    assert input =~ Jason.encode!([%{"id" => 19, "title" => "Interpret graphs"}])
    assert String.ends_with?(input, prompt)
  end

  test "revision separates the original, ordered history, and current change without duplicating it" do
    original = "Create a lab\nwith two tasks"
    history = ["Add feedback", "Change the chart"]
    current = "Make the final graph harder"

    {instructions, input} =
      Prompts.authoring(%{
        "source_build_id" => "completed-build",
        "prompt" => original,
        "skills" => [%{"id" => 19, "title" => "Interpret graphs"}],
        "revision_prompts" => history ++ [current],
        "revision_prompt" => current
      })

    assert instructions =~ "/workspace/.agents/skills/revise-interactive/SKILL.md"
    assert instructions =~ "/workspace/app"
    assert input =~ Jason.encode!(original)
    assert input =~ Jason.encode!(history)
    assert String.ends_with?(input, current)
    assert length(String.split(input, current)) == 2
  end

  test "a repeated request remains in historical context when it was also requested earlier" do
    {_, input} =
      Prompts.authoring(%{
        "source_build_id" => "completed-build",
        "prompt" => "Original",
        "revision_prompts" => ["Add feedback", "Add feedback"],
        "revision_prompt" => "Add feedback"
      })

    assert input =~ Jason.encode!(["Add feedback"])
    assert String.ends_with?(input, "Add feedback")
  end
end
