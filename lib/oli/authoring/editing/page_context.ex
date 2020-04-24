defmodule Oli.Authoring.Editing.ResourceContext do

  @derive Jason.Encoder
  defstruct [:graded, :authorEmail, :projectSlug, :resourceSlug, :title, :content, :objectives, :allObjectives, :editorMap, :activities]

end

