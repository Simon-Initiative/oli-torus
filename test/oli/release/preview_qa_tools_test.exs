defmodule Oli.Release.PreviewQAToolsTest do
  use Oli.DataCase

  import ExUnit.CaptureLog

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
      ["scenarios", "run", "--name", "one", "--file", "two"],
      ["projects", "ingest"],
      ["projects", "ingest", "--url", "https://example.test/archive.zip"],
      ["projects", "ingest", "--url", "one", "--author", "two", "extra"],
      ["projects", "ingest", "--url", "one", "--url", "two", "--author", "three"],
      ["projects", "ingest", "--url", "one", "--author", "two", "--unknown", "three"]
    ]

    assert Enum.all?(invalid, &(PreviewQATools.dispatch(&1, enabled?: true).status == 64))
  end

  test "project ingest options are order-independent" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()
    archive = zip_archive("valid")

    result =
      PreviewQATools.dispatch(
        [
          "projects",
          "ingest",
          "--author",
          "email:#{author.email}",
          "--url",
          "https://example.test/archive.zip"
        ],
        enabled?: true,
        request_fun: fn _url, _opts -> {:ok, {:download, 200, [archive]}} end,
        ingest_fun: fn _path, _author -> {:ok, %{id: 1, slug: "safe", title: "Safe"}} end,
        temp_root: temp_directory()
      )

    assert result.status == 0
  end

  test "project ingestion downloads bounded content, calls the existing ingest boundary, and cleans up" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()
    temp_root = temp_directory()
    test_process = self()
    archive = zip_archive("archive bytes")

    request_fun = fn url, _opts ->
      send(test_process, {:requested, url})
      {:ok, {:download, 200, [archive]}}
    end

    ingest_fun = fn path, selected_author ->
      send(test_process, {
        :ingested,
        selected_author.id,
        path,
        File.stat!(path).mode,
        File.stat!(Path.dirname(path)).mode
      })

      {:ok, %{id: 42, slug: "imported-project", title: "Imported Project"}}
    end

    result =
      PreviewQATools.dispatch(
        [
          "projects",
          "ingest",
          "--url",
          "https://example.test/archive.zip",
          "--author",
          "email:#{author.email}"
        ],
        enabled?: true,
        request_fun: request_fun,
        ingest_fun: ingest_fun,
        temp_root: temp_root,
        project_ingest_max_bytes: byte_size(archive)
      )

    assert result.status == 0
    assert result.output =~ "project_ingest"
    assert result.output =~ "imported-project"
    refute result.output =~ author.email
    assert_received {:requested, "https://example.test/archive.zip"}
    author_id = author.id
    assert_received {:ingested, ^author_id, archive_path, file_mode, directory_mode}
    assert Bitwise.band(file_mode, 0o777) == 0o600
    assert Bitwise.band(directory_mode, 0o777) == 0o700
    refute File.exists?(archive_path)
    assert File.ls!(temp_root) == []
  end

  test "project ingestion accepts both URL schemes and rejects all others before download" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()
    test_process = self()

    request_fun = fn url, _opts ->
      send(test_process, {:requested, url})
      {:ok, {:download_error, :closed}}
    end

    for scheme <- ["http", "https"] do
      expected_url = "#{scheme}://example.test/archive.zip"

      result =
        PreviewQATools.dispatch(
          [
            "projects",
            "ingest",
            "--url",
            expected_url,
            "--author",
            "email:#{author.email}"
          ],
          enabled?: true,
          request_fun: request_fun,
          temp_root: temp_directory()
        )

      assert result.result_code == "download_failed"
      assert_received {:requested, ^expected_url}
    end

    result =
      PreviewQATools.dispatch(
        [
          "projects",
          "ingest",
          "--url",
          "file:///etc/passwd",
          "--author",
          "email:#{author.email}"
        ],
        enabled?: true,
        request_fun: request_fun
      )

    assert result.result_code == "invalid_url"
    refute_received {:requested, _url}
  end

  test "project ingestion resolves only one active explicit author" do
    admin_id = Oli.Accounts.SystemRole.role_id().system_admin
    Oli.Utils.Seeder.AccountsFixtures.author_fixture(system_role_id: admin_id)
    Oli.Utils.Seeder.AccountsFixtures.author_fixture(system_role_id: admin_id)

    ambiguous =
      PreviewQATools.dispatch(
        [
          "projects",
          "ingest",
          "--url",
          "https://example.test/archive.zip",
          "--author",
          "default_admin"
        ],
        enabled?: true
      )

    assert ambiguous.result_code == "author_ambiguous"

    locked = Oli.Utils.Seeder.AccountsFixtures.author_fixture()

    locked
    |> Ecto.Changeset.change(locked_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Oli.Repo.update!()

    inactive =
      PreviewQATools.dispatch(
        [
          "projects",
          "ingest",
          "--url",
          "https://example.test/archive.zip",
          "--author",
          "email:#{locked.email}"
        ],
        enabled?: true
      )

    assert inactive.result_code == "author_not_found"
  end

  test "project ingestion bounds bytes, failures, output, logs, and temporary storage" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()
    secret_url = "https://user:password@example.test/archive.zip?token=secret"
    archive = zip_archive("safe")

    cases = [
      {{:download, 200, [archive]}, byte_size(archive), "ok"},
      {{:download, 200, [archive]}, byte_size(archive) - 1, "download_too_large"},
      {{:download, 302, []}, byte_size(archive), "download_status"},
      {{:download_error, :redirect_loop}, byte_size(archive), "download_failed"},
      {{:download_error, :timeout}, byte_size(archive), "download_timeout"}
    ]

    log =
      capture_log(fn ->
        Enum.each(cases, fn {response, max_bytes, expected_code} ->
          temp_root = temp_directory()

          result =
            PreviewQATools.dispatch(
              ["projects", "ingest", "--url", secret_url, "--author", "email:#{author.email}"],
              enabled?: true,
              request_fun: fn _url, _opts -> {:ok, response} end,
              ingest_fun: fn _path, _author ->
                {:ok, %{id: 1, slug: "safe", title: "Safe"}}
              end,
              temp_root: temp_root,
              project_ingest_max_bytes: max_bytes
            )

          assert result.result_code == expected_code
          refute result.output =~ "password"
          refute result.output =~ "secret"
          refute result.output =~ author.email
          assert File.ls!(temp_root) == []
        end)
      end)

    refute log =~ "password"
    refute log =~ "secret"
  end

  test "project ingest failures report partial mutation only after ingest starts" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()
    temp_root = temp_directory()
    archive = zip_archive("valid archive")

    result =
      PreviewQATools.dispatch(
        [
          "projects",
          "ingest",
          "--url",
          "https://example.test/archive.zip",
          "--author",
          "email:#{author.email}"
        ],
        enabled?: true,
        request_fun: fn _url, _opts -> {:ok, {:download, 200, [archive]}} end,
        ingest_fun: fn _path, _author -> {:error, "archive secret details"} end,
        temp_root: temp_root
      )

    assert result.result_code == "ingest_failed"
    assert result.output =~ "\"partial_mutations_possible\":true"
    refute result.output =~ "archive secret details"
    assert File.ls!(temp_root) == []
  end

  test "project ingestion rejects unsafe archive expansion before ingest starts" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()
    archive = zip_archive(String.duplicate("a", 10_000))

    result =
      PreviewQATools.dispatch(
        [
          "projects",
          "ingest",
          "--url",
          "https://example.test/archive.zip",
          "--author",
          "email:#{author.email}"
        ],
        enabled?: true,
        request_fun: fn _url, _opts -> {:ok, {:download, 200, [archive]}} end,
        ingest_fun: fn _path, _author -> flunk("unsafe archive must not be ingested") end,
        temp_root: temp_directory(),
        project_ingest_max_uncompressed_bytes: 9_999
      )

    assert result.result_code == "invalid_archive"
    assert result.output =~ "\"partial_mutations_possible\":false"
  end

  test "exceptions preserve pre-ingest versus ingest partial-mutation semantics" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()

    args = [
      "projects",
      "ingest",
      "--url",
      "https://example.test/archive.zip",
      "--author",
      "email:#{author.email}"
    ]

    request_failure =
      PreviewQATools.dispatch(args,
        enabled?: true,
        request_fun: fn _url, _opts -> raise "secret request failure" end,
        temp_root: temp_directory()
      )

    assert request_failure.result_code == "download_failed"
    assert request_failure.output =~ "\"partial_mutations_possible\":false"

    archive = zip_archive("valid")

    ingest_failure =
      PreviewQATools.dispatch(args,
        enabled?: true,
        request_fun: fn _url, _opts -> {:ok, {:download, 200, [archive]}} end,
        ingest_fun: fn _path, _author -> raise "secret ingest failure" end,
        temp_root: temp_directory()
      )

    assert ingest_failure.result_code == "ingest_failed"
    assert ingest_failure.output =~ "\"partial_mutations_possible\":true"
    refute ingest_failure.output =~ "secret"
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

  defp temp_directory do
    path = Path.join(System.tmp_dir!(), "release-cli-test-#{System.unique_integer([:positive])}")
    File.mkdir!(path)
    on_exit(fn -> File.rm_rf(path) end)
    path
  end

  defp zip_archive(contents) do
    {:ok, {_name, archive}} =
      :zip.create(~c"project.zip", [{~c"content.txt", contents}], [:memory])

    archive
  end
end
