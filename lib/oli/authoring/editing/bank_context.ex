defmodule Oli.Authoring.Editing.BankContext do
  @derive Jason.Encoder
  defstruct [
    :authorEmail,
    :projectSlug,
    :allObjectives,
    :loWellFormed,
    :allTags,
    :editorMap,
    :totalCount,
    :revisionHistoryLink,
    :allowTriggers
  ]
end
