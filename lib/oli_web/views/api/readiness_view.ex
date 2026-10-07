defmodule OliWeb.ReadinessView do
  use OliWeb, :view

  @version Application.compile_env!(:oli, [:build, :version])
  @sha Application.compile_env!(:oli, [:build, :sha])

  @doc "Renders only status and the compiled version/SHA, never runtime configuration."
  def render("index.json", %{status: status}) do
    %{status: status, version: @version, sha: @sha}
  end
end
