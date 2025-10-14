# test/support/python_runner.ex
defmodule Oli.PythonRunner do
  @moduledoc false

  @spec run(String.t(), [String.t()] | nil, keyword) ::
          {:ok, String.t()} | {:error, String.t(), integer}
  def run(code_or_script_path, args \\ [], opts \\ []) do
    python = python_exe()

    {cmd_args, _exec_opts} =
      case Keyword.get(opts, :mode, :inline) do
        :inline ->
          # run inline python (no temp files needed)
          {["-c", code_or_script_path], []}

        :script ->
          # run a .py file at path in code_or_script_path
          {[code_or_script_path | args], []}
      end

    # e.g. [{"PYTHONPATH", "/path"}]
    env = Keyword.get(opts, :env, [])
    cd = Keyword.get(opts, :cd)

    system_opts = [env: env, stderr_to_stdout: false]
    system_opts = if cd, do: Keyword.put(system_opts, :cd, cd), else: system_opts

    {out, status} = System.cmd(python, cmd_args, system_opts)

    if status == 0, do: {:ok, out}, else: {:error, out, status}
  end

  def available?(), do: python_exe() != nil

  defp python_exe() do
    System.get_env(
      "PYTHON",
      System.find_executable("python3") || System.find_executable("python")
    )
  end
end
