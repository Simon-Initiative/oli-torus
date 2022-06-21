defmodule Oli.Authoring.Editing.BibliographyContext do
  @derive Jason.Encoder
  defstruct [
    :authorEmail,
    :projectSlug,
    :totalCount
  ]
end
