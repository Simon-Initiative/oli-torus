defmodule Oli.GoogleDocs.FixturesTest do
  use ExUnit.Case, async: true

  import Mox

  alias HTTPoison.Response
  alias Oli.GoogleDocsImport.TestHelpers
  alias Oli.Test.MockHTTP

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "available fixtures are enumerated and sorted" do
    assert TestHelpers.available_fixtures() == [
             "activities.md",
             "baseline.md",
             "custom_elements.md",
             "media.md"
           ]
  end

  test "load_fixture parses front matter and body" do
    fixture = TestHelpers.load_fixture(:baseline)

    assert fixture.name == "baseline.md"
    assert fixture.metadata["title"] =~ "Baseline content"
    assert String.contains?(fixture.body, "# Getting Started with Cloud Security")
  end

  test "expect_markdown_fetch stubs a successful HTTP response" do
    file_id = "abc123"
    TestHelpers.expect_markdown_fetch(file_id, :custom_elements)

    assert {:ok, %Response{status_code: 200, body: body, headers: headers}} =
             MockHTTP.get(TestHelpers.markdown_export_url(file_id), [], [])

    assert String.contains?(body, "CustomElement")
    assert {"content-type", "text/markdown; charset=UTF-8"} in headers
  end

  test "expect_markdown_fetch can stub error responses" do
    file_id = "timeout123"
    TestHelpers.expect_markdown_fetch(file_id, :baseline, error: :timeout)

    assert {:error, :timeout} =
             MockHTTP.get(TestHelpers.markdown_export_url(file_id), [], [])
  end

  test "fixture_path resolves atoms and strings" do
    assert TestHelpers.fixture_path(:media) ==
             TestHelpers.fixture_path("media")
  end
end
