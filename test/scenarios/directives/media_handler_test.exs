defmodule Oli.Scenarios.Directives.MediaHandlerTest do
  use Oli.DataCase, async: true

  import Oli.Factory

  alias Oli.Scenarios.Directives.MediaHandler
  alias Oli.Scenarios.DirectiveTypes.{MediaDirective, ExecutionState}
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

  test "uploads media from absolute path" do
    project = insert(:project)

    tmp =
      Path.join(System.tmp_dir!(), "media-handler-abs-#{System.unique_integer([:positive])}.txt")

    File.write!(tmp, "hello")
    on_exit(fn -> File.rm_rf(tmp) end)

    state = %ExecutionState{projects: %{"proj" => built_project(project)}}

    assert {:error, msg} =
             MediaHandler.handle(
               %MediaDirective{project: "proj", path: tmp, mime: "text/plain"},
               state
             )

    assert msg =~ "{:persistence}"
  end

  test "resolves relative path with current_dir" do
    project = insert(:project)

    tmpdir =
      Path.join(System.tmp_dir!(), "media-handler-rel-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmpdir)
    file = Path.join(tmpdir, "x.txt")
    File.write!(file, "hi")
    on_exit(fn -> File.rm_rf(tmpdir) end)

    state =
      %ExecutionState{projects: %{"proj" => built_project(project)}}
      |> Map.put(:current_dir, tmpdir)

    assert {:error, msg} =
             MediaHandler.handle(
               %MediaDirective{project: "proj", path: "x.txt", mime: "text/plain"},
               state
             )

    assert msg =~ "{:persistence}"
  end
end
