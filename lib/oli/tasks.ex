defmodule Oli.Tasks do
  @moduledoc """
  Convenience wrappers around async task helpers that integrate with the
  Ecto SQL sandbox during tests.

  Ecto ties each checked-out connection to the process that owns it. When the
  application starts background tasks during a test run, those tasks live in
  separate processes and would normally raise `DBConnection.OwnershipError`
  errors as soon as they hit the database. By funnelling task creation through
  these helpers we automatically `allow/3` the sandbox connection to the newly
  spawned process when the environment is `:test`, keeping the noisy ownership
  errors out of the test logs while leaving production behaviour unchanged.
  """

  alias Ecto.Adapters.SQL.Sandbox

  @default_supervisor Oli.TaskSupervisor

  @doc """
  Starts a child process under the given supervisor (defaults to
  `Oli.TaskSupervisor`). In the test environment the child is granted access to
  the parent's SQL sandbox connection before the provided function executes.

  Pass `sync_in_test: true` when the caller needs the work to complete before
  the test process continues (useful for hotspots that would otherwise spawn a
  task and immediately exit, producing sandbox ownership warnings).
  """
  def start_child(fun, opts \\ []) when is_function(fun, 0) do
    supervisor = Keyword.get(opts, :supervisor, @default_supervisor)
    owner = Keyword.get(opts, :owner, self())
    sync_in_test? = Keyword.get(opts, :sync_in_test, false)

    if sync_in_test? and Application.get_env(:oli, :env) == :test do
      fun.()
      {:ok, self()}
    else
      Task.Supervisor.start_child(supervisor, fn ->
        maybe_allow_repo(owner)
        fun.()
      end)
    end
  end

  @doc """
  Like `start_child/2`, but returns the `%Task{}` produced by
  `Task.Supervisor.async_nolink/3`.
  """
  def async_nolink(fun, opts \\ []) when is_function(fun, 0) do
    supervisor = Keyword.get(opts, :supervisor, @default_supervisor)
    owner = Keyword.get(opts, :owner, self())

    Task.Supervisor.async_nolink(supervisor, fn ->
      maybe_allow_repo(owner)
      fun.()
    end)
  end

  @doc """
  Wrapper around `Task.async/1` that mirrors the sandbox behaviour of
  `start_child/2`.
  """
  def async(fun, opts \\ []) when is_function(fun, 0) do
    owner = Keyword.get(opts, :owner, self())

    Task.async(fn ->
      maybe_allow_repo(owner)
      fun.()
    end)
  end

  defp maybe_allow_repo(owner) do
    if Application.get_env(:oli, :env) == :test do
      Sandbox.allow(Oli.Repo, owner, self())
    end
  end
end
