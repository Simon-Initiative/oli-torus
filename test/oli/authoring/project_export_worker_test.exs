defmodule Oli.Authoring.ProjectExportWorkerTest do
  use Oli.DataCase

  alias Oli.Authoring.Course
  alias Oli.Authoring.ProjectExportWorker

  @local_output_dir_env "PROJECT_EXPORT_LOCAL_OUTPUT_DIR"

  describe "export/1" do
    test "writes the project export to a local directory when configured" do
      previous_output_dir = System.get_env(@local_output_dir_env)

      output_dir =
        Path.join(System.tmp_dir!(), "project-export-#{System.unique_integer([:positive])}")

      on_exit(fn ->
        File.rm_rf!(output_dir)

        case previous_output_dir do
          nil -> System.delete_env(@local_output_dir_env)
          value -> System.put_env(@local_output_dir_env, value)
        end
      end)

      System.put_env(@local_output_dir_env, output_dir)

      author = author_fixture()
      project_or_map = project_fixture(author, "project export local output")
      project = Map.get(project_or_map, :project, project_or_map)

      {export_url, timestamp} = ProjectExportWorker.export(project.slug)

      assert String.starts_with?(export_url, "file://")

      export_file =
        output_dir
        |> Path.join("exports/#{project.slug}/**/export_#{project.slug}.zip")
        |> Path.wildcard()
        |> List.first()

      assert is_binary(export_file)
      assert File.exists?(export_file)
      assert File.read!(export_file) |> binary_part(0, 2) == "PK"

      updated_project = Course.get_project_by_slug(project.slug)
      assert updated_project.latest_export_url == export_url
      assert updated_project.latest_export_timestamp == DateTime.truncate(timestamp, :second)
    end
  end
end
