defmodule Oli.TestHelper do
  def configure_tests(:hound) do
    File.mkdir_p!("test-results/screenshots")
    Application.ensure_all_started(:ex_machina)
    Application.ensure_all_started(:hound)
    ExUnit.start(exclude: [:test], include: [:hound])

    # We can't use manual SQL sandbox mode here, because torus attempts to run
    # several queries at startup that fail in that mode. However, the tests do
    # requre the SQL sandbox, so we set up a shared strategy here at the outset.
    # This means we should refrain from making these tests async for now.
    # TODO: What's a better way to handle this?
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Oli.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, {:shared, self()})
  end

  def configure_tests(_) do
    Application.ensure_all_started(:ex_machina)
    ExUnit.start(exclude: [:skip, :hound])
    Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, :manual)
  end
end

Oli.TestHelper.configure_tests(Mix.env())
