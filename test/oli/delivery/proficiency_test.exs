defmodule Oli.Delivery.ProficiencyTest do
  use ExUnit.Case, async: false

  alias Oli.Delivery.Proficiency
  alias Oli.Delivery.Sections.Section

  test "selects providers only from the persisted Section model" do
    assert {:ok, Oli.Delivery.Proficiency.Naive} =
             Proficiency.provider_for(%Section{learning_model_version: :naive})

    assert {:ok, Oli.Delivery.Proficiency.LktAoa} =
             Proficiency.provider_for(%Section{learning_model_version: :lkt_aoa})

    assert {:error, {:unsupported_learning_model, :other}} =
             Proficiency.provider_for(%Section{learning_model_version: :other})
  end

  test "analytics_version does not participate in dispatch" do
    for analytics_version <- [:v1, :v2] do
      assert {:ok, Oli.Delivery.Proficiency.Naive} =
               Proficiency.provider_for(%Section{
                 analytics_version: analytics_version,
                 learning_model_version: :naive
               })
    end
  end

  test "rejects model override options before provider execution" do
    section = %Section{learning_model_version: :naive}

    assert {:error, {:invalid_option, :model}} =
             Proficiency.estimates_for_objectives(section, [1], [2], model: :lkt_aoa)

    assert {:error, {:invalid_option, :learning_model_version}} =
             Proficiency.estimates_for_scopes(section, [1], [:course],
               learning_model_version: :lkt_aoa
             )
  end

  test "delegates every facade operation with the Section and arguments intact" do
    configure_test_providers()
    section = %Section{id: 10, learning_model_version: :naive}

    assert {:ok, {:naive, :objectives, ^section, [1], [2], [include: :evidence]}} =
             Proficiency.estimates_for_objectives(section, [1], [2], include: :evidence)

    assert {:ok, {:naive, :scopes, ^section, [1], [:course], []}} =
             Proficiency.estimates_for_scopes(section, [1], [:course])

    assert {:ok, {:naive, :objective_aggregates, ^section, [2], []}} =
             Proficiency.objective_aggregates(section, [2])

    assert {:ok, {:naive, :scope_aggregates, ^section, [:course], []}} =
             Proficiency.scope_aggregates(section, [:course])
  end

  test "facade execution follows the lkt_aoa Section model" do
    configure_test_providers()
    section = %Section{id: 10, learning_model_version: :lkt_aoa}

    assert {:ok, {:lkt_aoa, :scopes, ^section, [1], [:course], []}} =
             Proficiency.estimates_for_scopes(section, [1], [:course])
  end

  test "fails explicitly when the selected provider lacks an operation" do
    configure_test_providers()
    section = %Section{learning_model_version: :lkt_aoa}

    assert {:error, {:provider_unavailable, :lkt_aoa}} =
             Proficiency.objective_aggregates(section, [1])
  end

  defp configure_test_providers do
    previous = Application.get_env(:oli, :proficiency_providers)

    Application.put_env(:oli, :proficiency_providers, %{
      naive: Oli.Test.Proficiency.NaiveProvider,
      lkt_aoa: Oli.Test.Proficiency.LktAoaProvider
    })

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:oli, :proficiency_providers)
        providers -> Application.put_env(:oli, :proficiency_providers, providers)
      end
    end)
  end
end
