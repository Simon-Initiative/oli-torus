defmodule AuditBoundaryCheck do
  @moduledoc false

  @fixture_dir "test/fixtures/audit_boundary"
  @source_dir "audit_boundary_sources"

  @doc false
  def run do
    root = File.cwd!()
    env = System.get_env("MIX_ENV", "dev")
    build = Path.join(root, "_build/#{env}")

    tmp =
      Path.join(
        System.tmp_dir!(),
        "oli-audit-boundary-#{System.pid()}-#{System.unique_integer([:positive])}"
      )

    case File.regular?(Path.join(build, "lib/oli/ebin/oli.app")) do
      true -> :ok
      false -> raise "Run MIX_ENV=#{env} mix compile --force --warnings-as-errors first"
    end

    File.mkdir!(tmp)

    try do
      prepare!(root, build, tmp, env)
      compile!(tmp, "baseline", :allowed, ["--force"])
      install!(root, tmp, "allowed.ex.fixture")
      compile!(tmp, "public facade, legacy calls, and internal calls", :allowed)

      cases = [
        {"read_direct.ex.fixture", "Oli.Accounts.Audited.Mutations"},
        {"web_alias.ex.fixture", "Oli.Accounts.Audited.Mutations"},
        {"scenario_capture.ex.fixture", "Oli.Accounts.Audited.Mutations"},
        {"read_replay.ex.fixture", "Oli.Accounts.Audited.Replay"},
        {"web_replay.ex.fixture", "Oli.Accounts.Audited.Replay"},
        {"scenario_replay.ex.fixture", "Oli.Accounts.Audited.Replay"},
        {"import.ex.fixture", "Oli.Accounts.Audited.CompilerProbe"},
        {"mix_mutations.ex.fixture", "Oli.Accounts.Audited.Mutations"},
        {"mix_replay.ex.fixture", "Oli.Accounts.Audited.Replay"}
      ]

      cases =
        case env do
          "test" -> cases ++ [{"test_support.ex.fixture", "Oli.Accounts.Audited.Mutations"}]
          _ -> cases
        end

      for {file, target} <- cases do
        install!(root, tmp, file)
        compile!(tmp, file, {:forbidden, target})
        File.rm!(Path.join([tmp, @source_dir, "probe.ex"]))
        compile!(tmp, "recovery after #{file}", :allowed)
      end

      IO.puts("Audit boundary checks passed (#{env}, #{length(cases)} forbidden cases).")
    after
      File.rm_rf!(tmp)
    end
  end

  defp prepare!(root, build, tmp, env) do
    for path <- ~w(lib config seeding test priv assets rel deps) do
      source = Path.join(root, path)

      case File.exists?(source) do
        true -> File.ln_s!(source, Path.join(tmp, path))
        false -> :ok
      end
    end

    # Gleam stages generated files during compilation; keep those writes isolated.
    File.cp_r!(Path.join(root, "gleam"), Path.join(tmp, "gleam"))
    File.cp!(Path.join(root, "mix.lock"), Path.join(tmp, "mix.lock"))

    original = File.read!(Path.join(root, "mix.exs"))
    selector = "elixirc_paths: elixirc_paths(Mix.env()),"

    case String.split(original, selector) do
      [before, rest] ->
        File.write!(
          Path.join(tmp, "mix.exs"),
          before <> "elixirc_paths: elixirc_paths(Mix.env()) ++ [\"#{@source_dir}\"]," <> rest
        )

      _ ->
        raise "Cannot locate the project's elixirc_paths; update this verification runner"
    end

    target_lib = Path.join(tmp, "_build/#{env}/lib")
    File.mkdir_p!(target_lib)

    for path <- Path.wildcard(Path.join(build, "lib/*")) do
      target = Path.join(target_lib, Path.basename(path))

      case Path.basename(path) do
        "oli" -> File.cp_r!(path, target)
        _ -> File.ln_s!(path, target)
      end
    end

    File.mkdir_p!(Path.join(tmp, @source_dir))
  end

  defp install!(root, tmp, file) do
    name =
      case file do
        "allowed.ex.fixture" -> "allowed.ex"
        _ -> "probe.ex"
      end

    File.cp!(Path.join([root, @fixture_dir, file]), Path.join([tmp, @source_dir, name]))
  end

  defp compile!(tmp, label, expectation, extra_args \\ []) do
    {output, status} =
      System.cmd("mix", ["compile", "--warnings-as-errors" | extra_args],
        cd: tmp,
        stderr_to_stdout: true,
        env: [{"MIX_BUILD_PATH", nil}, {"MIX_DEPS_PATH", nil}]
      )

    valid? =
      case expectation do
        :allowed ->
          status == 0

        {:forbidden, target} ->
          status != 0 and
            String.contains?(output, "forbidden reference to #{target}") and
            String.contains?(output, "is not exported by its owner boundary Oli.Accounts.Audited") and
            String.contains?(output, "#{@source_dir}/probe.ex:") and
            not String.contains?(output, "Compilation error")
      end

    case valid? do
      true -> IO.puts("PASS #{label}")
      false -> raise "Boundary check failed: #{label} (exit #{status})\n#{output}"
    end
  end
end

AuditBoundaryCheck.run()
