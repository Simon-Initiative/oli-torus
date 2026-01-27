defmodule Oli.Repo.Migrations.GenAISecondaryModelAndPoolClassTest do
  use Oli.DataCase

  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.Repo

  test "registered_models defaults pool_class to slow" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {1, [%{id: id}]} =
      Repo.insert_all(
        "registered_models",
        [
          %{
            name: "Default Model",
            provider: "open_ai",
            model: "gpt-4",
            url_template: "https://api.example.com",
            api_key: nil,
            timeout: 8000,
            recv_timeout: 60_000,
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id]
      )

    model = Repo.get!(RegisteredModel, id)
    assert model.pool_class == :slow
    assert model.max_concurrent == nil
  end

  test "max_concurrent must be non-negative" do
    assert_raise Ecto.ConstraintError, ~r/max_concurrent_non_negative/, fn ->
      Repo.insert!(%RegisteredModel{
        name: "Invalid Model",
        provider: :open_ai,
        model: "gpt-4",
        url_template: "https://api.example.com",
        api_key: "secret",
        timeout: 8000,
        recv_timeout: 60_000,
        pool_class: :slow,
        max_concurrent: -1
      })
    end
  end

  test "secondary_model_id is persisted" do
    primary = insert_registered_model(%{name: "Primary", model: "gpt-4"})
    secondary = insert_registered_model(%{name: "Secondary", model: "gpt-4.1"})

    service_config =
      Repo.insert!(%ServiceConfig{
        name: "Config",
        primary_model_id: primary.id,
        secondary_model_id: secondary.id
      })

    assert service_config.secondary_model_id == secondary.id
  end

  defp insert_registered_model(attrs) do
    defaults = %{
      name: "Default Model",
      provider: :open_ai,
      model: "gpt-4",
      url_template: "https://api.example.com",
      api_key: "secret",
      timeout: 8000,
      recv_timeout: 60_000,
      pool_class: :slow
    }

    Repo.insert!(struct(RegisteredModel, Map.merge(defaults, attrs)))
  end
end
