defmodule OliWeb.ReadinessView do
  use OliWeb, :view

  @build_identity (case Application.compile_env!(:oli, [:build, :env]) do
                     :playwright ->
                       %{
                         version: Application.compile_env!(:oli, [:build, :version]),
                         sha: Application.compile_env!(:oli, [:build, :sha])
                       }

                     _ ->
                       %{}
                   end)

  @doc "Renders status, including compiled version/SHA only in Playwright builds."
  def render("index.json", %{status: status}) do
    Map.put(@build_identity, :status, status)
  end
end
