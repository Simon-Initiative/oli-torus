# Acceptance coverage: AC-003.
defmodule Oli.GenAI.ProviderDesignationConcurrencyTest do
  use ExUnit.Case, async: false
  import Ecto.Query
  alias Oli.{GenAI, Repo}
  alias Oli.GenAI.Provider
  alias Oli.GenAI.Completions.RegisteredModel

  test "fallback designation across connections cannot overwrite a later atomic administrator selection" do
    provider =
      unboxed(fn ->
        {:ok, provider} =
          GenAI.create_provider(%{
            name: "Concurrent designation",
            adapter: :open_ai,
            api_key: "dummy-key",
            base_url: "http://127.0.0.1:9999"
          })

        provider
      end)

    on_exit(fn ->
      ExUnit.CaptureLog.capture_log(fn ->
        unboxed(fn ->
          Repo.delete_all(from m in RegisteredModel, where: m.provider_id == ^provider.id)
          Repo.delete_all(from p in Provider, where: p.id == ^provider.id)
        end)
      end)
    end)

    [first, second] =
      unboxed(fn ->
        models =
          for name <- ["first", "second"] do
            {:ok, model} =
              GenAI.create_registered_model(%{
                name: name,
                model: name,
                provider: :open_ai,
                provider_id: provider.id,
                api_key: "dummy-legacy-key",
                url_template: provider.base_url
              })

            model
          end

        Repo.update_all(from(m in RegisteredModel, where: m.provider_id == ^provider.id),
          set: [health_check: false]
        )

        models
      end)

    parent = self()

    fallback =
      Task.async(fn ->
        unboxed(fn ->
          Repo.transaction(fn ->
            Repo.query!("SELECT pg_advisory_xact_lock(109492, 2)")
            send(parent, :designation_locked)

            receive do
              :continue -> :ok
            end

            GenAI.reconcile_probe_model(provider.id)
          end)
        end)
      end)

    assert_receive :designation_locked, 2_000

    admin =
      Task.async(fn ->
        unboxed(fn ->
          Repo.transaction(fn ->
            {:ok, _} = GenAI.update_registered_model(second, %{health_check: true})
            {:ok, _} = GenAI.update_registered_model(first, %{health_check: false})
            send(parent, :administrator_saved)
          end)
        end)
      end)

    refute_receive :administrator_saved, 30
    send(fallback.pid, :continue)
    assert {:ok, {:ok, selected}} = Task.await(fallback, 2_000)
    assert selected.id == first.id
    assert {:ok, :administrator_saved} = Task.await(admin, 2_000)
    assert_receive :administrator_saved, 2_000

    unboxed(fn ->
      assert {:ok, selected} = GenAI.reconcile_probe_model(provider.id)
      assert selected.id == second.id
      refute Repo.get!(RegisteredModel, first.id).health_check
    end)
  end

  defp unboxed(fun), do: Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fun)
end
