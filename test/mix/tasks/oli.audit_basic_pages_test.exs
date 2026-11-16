defmodule Mix.Tasks.Oli.AuditBasicPagesTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Oli.AuditBasicPages

  setup do
    directory =
      Path.join(System.tmp_dir!(), "basic-page-audit-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    %{directory: directory}
  end

  test "audits legacy pages read-only, skips other resources, and bounds diagnostics", %{
    directory: dir
  } do
    pages = %{
      "legacy.json" => %{"type" => "Page", "content" => %{"model" => []}},
      "invalid.json" => %{
        "version" => "0.1.0",
        "model" => [%{"type" => "content", "children" => [%{}]}]
      },
      "invalid2.json" => %{"version" => "0.1.0", "model" => false},
      "adaptive.json" => %{"advancedAuthoring" => true, "model" => []},
      "activity.json" => %{"type" => "Activity", "content" => %{"model" => []}}
    }

    for {name, content} <- pages, do: File.write!(Path.join(dir, name), Jason.encode!(content))
    before = Map.new(pages, fn {name, _} -> {name, File.read!(Path.join(dir, name))} end)

    output =
      capture_io(fn -> AuditBasicPages.run([Path.join(dir, "*.json"), "--max-errors", "1"]) end)

    report = Jason.decode!(output)
    assert report["checked"] == 3
    assert report["valid"] == 1
    assert report["invalid"] == 2
    assert report["skipped"] == 2
    assert report["legacy_envelopes"] == 1
    assert report["database_revisions"] == 0
    assert length(report["samples"]) == 1
    assert [%{"id" => _, "paths" => [_ | _]}] = report["samples"]
    for {name, bytes} <- before, do: assert(File.read!(Path.join(dir, name)) == bytes)
  end

  test "refuses an empty or invalid audit scope", %{directory: dir} do
    assert_raise Mix.Error, fn -> AuditBasicPages.run([]) end
    assert_raise Mix.Error, fn -> AuditBasicPages.run([Path.join(dir, "*.json")]) end
    assert_raise Mix.Error, fn -> AuditBasicPages.run(["--database", "--max-errors", "-1"]) end
  end

  test "can fail CI without printing submitted content", %{directory: dir} do
    path = Path.join(dir, "invalid.json")
    File.write!(path, Jason.encode!(%{"model" => [%{"type" => "secret-content"}]}))

    output =
      capture_io(fn ->
        assert_raise Mix.Error, fn -> AuditBasicPages.run([path, "--fail-on-invalid"]) end
      end)

    assert Jason.decode!(output)["invalid"] == 1
    refute output =~ "secret-content"
  end

  test "rejects Page exports without content and skips typed non-page resources with a model", %{
    directory: dir
  } do
    File.write!(Path.join(dir, "page.json"), Jason.encode!(%{"type" => "Page"}))

    File.write!(
      Path.join(dir, "activity.json"),
      Jason.encode!(%{"type" => "Activity", "model" => []})
    )

    output =
      capture_io(fn ->
        assert_raise Mix.Error, fn ->
          AuditBasicPages.run([Path.join(dir, "*.json"), "--fail-on-invalid"])
        end
      end)

    report = Jason.decode!(output)
    assert report["checked"] == 1
    assert report["invalid"] == 1
    assert report["skipped"] == 1
  end
end
