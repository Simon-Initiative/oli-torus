defmodule OliWeb.ReadinessViewTest do
  use ExUnit.Case, async: true

  @view_path Path.expand("../../../lib/oli_web/views/api/readiness_view.ex", __DIR__)

  for build_env <- [:playwright, :prod, :preview, :dev, :test, :ci_e2e] do
    @tag timeout: 120_000
    test "#{build_env} build fixes readiness metadata visibility at compile time" do
      executable = System.find_executable("elixir") || raise "elixir executable not found"

      code_paths =
        Enum.flat_map(:code.get_path(), fn path -> ["-pa", List.to_string(path)] end)

      script = ~S'''
      import ExUnit.Assertions

      [build_env, view_path] = System.argv()
      build_env = String.to_atom(build_env)
      Application.put_env(:oli, :build, %{env: build_env, version: "1.2.3", sha: "compiled-sha"})
      # Replace the test build's view only in this isolated VM.
      Code.compiler_options(ignore_module_conflict: true)
      Code.compile_file(view_path)

      expected_identity =
        case build_env do
          :playwright -> %{version: "1.2.3", sha: "compiled-sha"}
          _ -> %{}
        end

      for runtime_env <- [:prod, :playwright] do
        Application.put_env(:oli, :env, runtime_env)
        Application.put_env(:oli, :build, %{
          env: runtime_env, version: "runtime-version", sha: "runtime-sha", secret: "private"
        })

        for status <- ["ready", "not_ready"] do
          assert OliWeb.ReadinessView.render("index.json", %{status: status}) ==
                   Map.put(expected_identity, :status, status)
        end
      end
      '''

      {output, exit_status} =
        System.cmd(
          executable,
          code_paths ++ ["-e", script, "--", Atom.to_string(unquote(build_env)), @view_path],
          stderr_to_stdout: true
        )

      assert exit_status == 0, output
      assert output == ""
    end
  end
end
