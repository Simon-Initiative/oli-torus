defmodule Oli.Authoring.Editing.ResourceContext do

  @derive Jason.Encoder
  defstruct [:resourceType, :authorEmail, :projectSlug, :resourceSlug, :title, :content, :objectives, :allObjectives, :editorMap]

end

