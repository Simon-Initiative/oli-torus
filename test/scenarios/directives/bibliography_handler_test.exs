defmodule Oli.Scenarios.Directives.BibliographyHandlerTest do
  use Oli.DataCase, async: true

  import Oli.Factory
  alias Oli.Authoring.Course

  alias Oli.Scenarios.Directives.BibliographyHandler
  alias Oli.Scenarios.DirectiveTypes.{BibliographyDirective, ExecutionState}
  alias Oli.Scenarios.Types.BuiltProject

  defp built_project(project) do
    %BuiltProject{
      project: project,
      working_pub: nil,
      root: nil,
      id_by_title: %{},
      rev_by_title: %{},
      objectives_by_title: %{},
      tags_by_title: %{}
    }
  end

  test "adds bibliography entry" do
    author = insert(:author)
    {:ok, %{project: project}} = Course.create_project("bib test", author)

    state = %ExecutionState{
      current_author: author,
      projects: %{"proj" => built_project(project)}
    }

    assert {:ok, _} =
             BibliographyHandler.handle(
               %BibliographyDirective{project: "proj", entry: "@book{key,title={Hi}}"},
               state
             )
  end
end
