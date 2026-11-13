defmodule Oli.Interactives.Prompts do
  @moduledoc "Constructs thin skill-directed system instructions and complete authoring task inputs."

  @doc "Selects build/revise instructions and includes the original request, skill targets, and revision context."
  @spec authoring(map()) :: {String.t(), String.t()}
  def authoring(inputs) do
    skills =
      "Selected project skills (numeric IDs and titles):\n#{Jason.encode!(inputs["skills"] || [])}"

    case inputs["source_build_id"] do
      nil ->
        {instructions(:build),
         "#{skills}\n\nHere is the author's prompt for the experience to build:\n#{inputs["prompt"]}"}

      _ ->
        current = inputs["revision_prompt"]
        history = inputs["revision_prompts"] || []

        previous =
          case List.last(history) == current do
            true -> Enum.drop(history, -1)
            false -> history
          end

        {instructions(:revise),
         "#{skills}\n\nOriginal author prompt:\n#{Jason.encode!(inputs["prompt"])}\n\nPrevious revision requests (oldest first; historical context):\n#{Jason.encode!(previous)}\n\nCurrent revision request (make these changes):\n#{current}"}
    end
  end

  @doc "Returns the system instruction that requires reading the appropriate hosted skill and its references."
  @spec instructions(:build | :revise) :: String.t()
  def instructions(:build) do
    """
    You are tasked with creating an interactive web-based learning experience for the OLI Torus educational platform.
    You must use the build-interactive skill: read /workspace/.agents/skills/build-interactive/SKILL.md and its required references before development, and follow them through testing and authoring handoff.
    The task input supplies selected project skills followed by the author's request for what to build.
    """
  end

  def instructions(:revise) do
    """
    You are tasked with revising an existing interactive learning experience previously built for the OLI Torus educational platform. Its current files are in /workspace/app.
    You must use the revise-interactive skill: read /workspace/.agents/skills/revise-interactive/SKILL.md and its required references before editing, and follow them through testing and authoring handoff.
    The task input supplies selected skills, the original prompt, ordered previous revision requests, and the current revision request. Use the history as context and make the precise changes requested in the current revision.
    """
  end
end
