defmodule OliWeb.Delivery.SectionPreviewRouteGuardTest do
  use ExUnit.Case, async: true

  # This is an intentional static guard. Student section preview and instructor preview share
  # nearby routes, so student/shared delivery navigation should go through the centralized
  # preview-aware route helpers instead of directly targeting the instructor preview lesson route.
  @guarded_file_patterns [
    "lib/oli_web/live/delivery/student/**/*.ex",
    "lib/oli_web/components/delivery/**/*.ex"
  ]

  @allowed_direct_instructor_preview_routes %{
    "lib/oli_web/live/delivery/student/utils.ex" => [
      "PreviewRoutes.lesson_path(section_slug, revision_slug, params)"
    ],
    "lib/oli_web/components/delivery/discussion_activity/discussion_table_model.ex" => [
      "PreviewRoutes.lesson_path(section_slug, post.slug)"
    ]
  }

  @direct_instructor_preview_lesson_route ~r/(PreviewRoutes|OliWeb\.Delivery\.Instructor\.PreviewRoutes)\.lesson_path\(/

  test "student and shared delivery navigation does not bypass section preview route helpers" do
    violations =
      @guarded_file_patterns
      |> Enum.flat_map(&Path.wildcard/1)
      |> Enum.flat_map(&direct_instructor_preview_lesson_route_occurrences/1)
      |> Enum.reject(&allowed_direct_instructor_preview_route?/1)

    assert violations == []
  end

  defp direct_instructor_preview_lesson_route_occurrences(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _line_number} ->
      Regex.match?(@direct_instructor_preview_lesson_route, line)
    end)
    |> Enum.map(fn {line, line_number} ->
      %{path: path, line_number: line_number, line: String.trim(line)}
    end)
  end

  defp allowed_direct_instructor_preview_route?(%{path: path, line: line}) do
    @allowed_direct_instructor_preview_routes
    |> Map.get(path, [])
    |> Enum.any?(&String.contains?(line, &1))
  end
end
