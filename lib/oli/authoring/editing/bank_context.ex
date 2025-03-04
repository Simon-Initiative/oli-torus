defmodule Oli.Authoring.Editing.BankContext do
  @derive Jason.Encoder
  defstruct [
    :authorEmail,
    :projectSlug,
    :allObjectives,
    :allTags,
    :editorMap,
    :totalCount,
    :revisionHistoryLink,
    :allowTriggers
  ]
end
