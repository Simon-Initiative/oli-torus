defmodule Oli.Interop.Ingest.Preprocessor.Common do
  @project_key "_project"
  @hierarchy_key "_hierarchy"
  @media_key "_media-manifest"

  def project_key(), do: @project_key
  def hierarchy_key(), do: @hierarchy_key
  def media_key(), do: @media_key

  def well_known_keys(), do: [project_key(), hierarchy_key(), media_key()]
end
