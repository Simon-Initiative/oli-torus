defmodule Oli.Release.PreviewQAToolsTest do
  use Oli.DataCase

  alias Oli.Release.PreviewQATools
  alias Oli.Release.PreviewQATools.BundledScenarios

  test "disabled commands fail before accessing their source" do
    result =
      PreviewQATools.dispatch(["scenarios", "run", "--file", "/does/not/exist"],
        enabled?: false
      )

    assert result.status == 77
    assert result.result_code == "disabled"
    assert result.output =~ "partial_mutations_possible"
  end

  test "strict argument parsing rejects malformed run commands" do
    invalid = [
      [],
      ["scenarios"],
      ["scenarios", "list", "extra"],
      ["scenarios", "run"],
      ["scenarios", "run", "--name"],
      ["scenarios", "run", "--unknown", "value"],
      ["scenarios", "run", "--name", "one", "--file", "two"]
    ]

    assert Enum.all?(invalid, &(PreviewQATools.dispatch(&1, enabled?: true).status == 64))
  end

  test "listing returns bounded immutable metadata" do
    result = PreviewQATools.dispatch(["scenarios", "list"], enabled?: true)

    assert result.status == 0, result.output
    assert result.output =~ "preview_smoke"
    assert result.output =~ "Creates a minimal preview-owned project"
    refute result.output =~ "ownership:"
  end

  test "custom files execute synchronously and report aggregate results" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()

    {:ok, institution} =
      Oli.Institutions.create_institution(%{
        name: "Release CLI Institution",
        country_code: "US",
        institution_email: "release-cli@example.edu",
        institution_url: "https://example.edu"
      })

    path =
      write_yaml("""
      - ownership:
          author: email:#{author.email}
          institution: id:#{institution.id}
      """)

    result = PreviewQATools.dispatch(["scenarios", "run", "--file", path], enabled?: true)

    assert result.status == 0
    assert result.result_code == "ok"
    assert result.output =~ "users_created"
    assert result.output =~ "\"source\":\"file\""
  end

  test "custom execution preserves use composition, hooks, and assertions" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()

    {:ok, institution} =
      Oli.Institutions.create_institution(%{
        name: "Composed Release Institution",
        country_code: "US",
        institution_email: "composed-release@example.edu",
        institution_url: "https://example.edu"
      })

    child =
      write_yaml("""
      - ownership:
          author: email:#{author.email}
          institution: id:#{institution.id}
      """)

    main =
      write_yaml("""
      - use:
          file: #{Path.basename(child)}
      - hook:
          function: Oli.Scenarios.Hooks.set_test_flag/1
      - assert:
          assertions:
            - release DSL remains available
      """)

    result = PreviewQATools.dispatch(["scenarios", "run", "--file", main], enabled?: true)

    assert result.status == 0, result.output
    assert result.output =~ "\"verifications_passed\":1"
  end

  test "release hooks do not create atoms from unknown module or function names" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()

    {:ok, institution} =
      Oli.Institutions.create_institution(%{
        name: "Safe Hook Institution",
        country_code: "US",
        institution_email: "safe-hook@example.edu",
        institution_url: "https://example.edu"
      })

    unknown = "Unknown#{System.unique_integer([:positive])}"

    path =
      write_yaml("""
      - ownership:
          author: email:#{author.email}
          institution: id:#{institution.id}
      - hook:
          function: Oli.Scenarios.#{unknown}.function/1
      """)

    result = PreviewQATools.dispatch(["scenarios", "run", "--file", path], enabled?: true)

    assert result.status == 1

    assert_raise ArgumentError, fn ->
      String.to_existing_atom("Elixir.Oli.Scenarios.#{unknown}")
    end
  end

  test "bundled registry exposes metadata and a packaged immutable path" do
    assert {:ok, metadata, path} = BundledScenarios.fetch("preview_smoke")
    assert metadata["version"] == "1"
    assert File.regular?(path)
    assert :ok = Oli.Scenarios.validate_file(path)
    assert {:error, :unknown_scenario} = BundledScenarios.fetch("missing")
  end

  test "custom scenario input is size bounded before parsing" do
    path = write_yaml(String.duplicate("x", 5_000_001))
    result = PreviewQATools.dispatch(["scenarios", "run", "--file", path], enabled?: true)

    assert result.status == 1
    assert result.result_code == "input_too_large"
    assert result.output =~ "5000000 byte limit"
  end

  test "parse failure reports that mutations did not begin" do
    path = write_yaml("invalid: [")
    result = PreviewQATools.dispatch(["scenarios", "run", "--file", path], enabled?: true)

    assert result.status == 1
    assert result.result_code == "parse_failed"
    assert result.output =~ "\"partial_mutations_possible\":false"
  end

  test "release use directives cannot bypass the cumulative input limit" do
    included = write_yaml(String.duplicate("x", 5_000_001))
    root = write_yaml("- use:\n    file: #{Path.basename(included)}\n")

    result = PreviewQATools.dispatch(["scenarios", "run", "--file", root], enabled?: true)

    assert result.status == 1
    assert result.output =~ "\"partial_mutations_possible\":true"
  end

  test "release use directives have a bounded nesting depth" do
    deepest = write_yaml("[]\n")

    root =
      Enum.reduce(1..21, deepest, fn _, child ->
        write_yaml("- use:\n    file: #{Path.basename(child)}\n")
      end)

    result = PreviewQATools.dispatch(["scenarios", "run", "--file", root], enabled?: true)

    assert result.status == 1
    assert result.output =~ "\"partial_mutations_possible\":true"
  end

  defp write_yaml(contents) do
    path = Path.join(System.tmp_dir!(), "release-cli-#{System.unique_integer([:positive])}.yaml")
    File.write!(path, contents)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
