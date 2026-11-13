defmodule OliWeb.Analytics.CatalogTest do
  use ExUnit.Case, async: true

  alias OliWeb.Analytics.Catalog

  @parity_cases "test/support/fixtures/analytics_event_catalog_parity.json"
  @doc_path "docs/features/analytics/ga-event-catalog.md"
  @runbook_path "docs/runbooks/google-analytics.md"

  # The same cases run through assets/src/analytics/catalog.ts in
  # assets/test/analytics/catalog_test.ts, so both emitters validate identically.
  test "validates emitter parameters exactly like the TypeScript writer" do
    for %{"description" => description, "name" => name, "params" => params} = test_case <-
          @parity_cases |> File.read!() |> Jason.decode!() do
      expected =
        case test_case["expected"] do
          nil -> :error
          %{"params" => kept, "dropped" => dropped} -> {:ok, kept, dropped}
        end

      assert Catalog.event_params(name, params) == expected, description
    end
  end

  test "events reference defined parameters and features map to defined areas" do
    catalog = Catalog.catalog()

    parameters =
      Map.merge(catalog["context_parameters"], catalog["event_parameters"])
      |> Map.merge(catalog["derived_parameters"])

    for {name, %{"parameters" => event_parameters}} <- catalog["events"] do
      assert Map.has_key?(event_parameters, "user_role"), name
      assert Map.has_key?(event_parameters, "page_area"), name

      for {parameter, true} <- event_parameters do
        assert Map.has_key?(parameters, parameter), "#{name} uses undefined #{parameter}"
      end
    end

    areas = catalog["derived_parameters"]["feature_area"]["values"]

    for {feature, %{"feature_area" => area}} <-
          catalog["event_parameters"]["feature_name"]["values"] do
      assert Map.has_key?(areas, area), "#{feature} has undefined area #{area}"
    end
  end

  test "the catalog document describes every event, parameter and value" do
    doc = File.read!(@doc_path)
    catalog = Catalog.catalog()

    for group <- ["context_parameters", "event_parameters", "derived_parameters"],
        {parameter, definition} <- catalog[group] do
      assert doc =~ "`#{parameter}`", "#{@doc_path} does not describe #{parameter}"

      for value <- Map.keys(Map.get(definition, "values", %{})) do
        assert doc =~ "`#{value}`", "#{@doc_path} does not describe #{parameter}=#{value}"
      end
    end

    for event <- Catalog.event_names() do
      assert doc =~ "`#{event}`", "#{@doc_path} does not describe #{event}"
    end
  end

  test "the runbook's GTM trigger matches exactly the catalogued events" do
    [_, names] = Regex.run(~r/`\^\(([a-z_|]+)\)\$`/, File.read!(@runbook_path))
    assert Enum.sort(String.split(names, "|")) == Enum.sort(Catalog.event_names())
  end
end
