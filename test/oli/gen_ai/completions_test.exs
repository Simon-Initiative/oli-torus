defmodule Oli.GenAI.CompletionsTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.{Provider, RoutingPlan}
  alias Oli.GenAI.Completions
  alias Oli.GenAI.Completions.RegisteredModel

  test "generation and streaming require explicit transport context" do
    model = %RegisteredModel{id: 1, provider_id: 2, model: "test"}
    assert {:error, :missing_transport_context} = Completions.generate([], [], model)

    assert {:error, :missing_transport_context} =
             Completions.stream([], [], model, fn _ -> flunk("unexpected output") end)
  end

  test "a selected OpenAI Provider requires a managed pool" do
    model = %RegisteredModel{id: 1, provider_id: 2, model: "test"}

    plan = %RoutingPlan{
      provider: %Provider{id: 2, adapter: :open_ai, api_key: "key"},
      selected_model: model
    }

    assert {:error, :missing_transport_context} =
             Completions.generate([], [], model, transport_context: plan)
  end

  test "a resolved null Provider supports local completions" do
    model = %RegisteredModel{id: 1, provider_id: 2, model: "test"}
    plan = %RoutingPlan{provider: %Provider{id: 2, adapter: :null}, selected_model: model}
    assert {:ok, _} = Completions.generate([], [], model, transport_context: plan)
  end

  test "unsupported and disabled Providers cannot dispatch legacy adapters" do
    model = %RegisteredModel{id: 1, provider_id: 2, model: "test"}
    plan = %RoutingPlan{provider: %Provider{id: 2, adapter: :claude}, selected_model: model}

    assert {:error, :unsupported_adapter} =
             Completions.generate([], [], model, transport_context: plan)

    plan = %{plan | provider: %{plan.provider | enabled: false}}

    assert {:error, :provider_ineligible} =
             Completions.generate([], [], model, transport_context: plan)
  end
end
