defmodule Oli.Validation.PageDomainTest do
  use ExUnit.Case, async: true

  alias Oli.Validation
  alias Oli.Utils.{JSONValidation, SchemaResolver}

  defp page(model), do: %{"version" => "0.1.0", "model" => model}

  defp activity(id, placement),
    do: %{"type" => "activity-reference", "activity_id" => id, "id" => placement}

  defp selection(logic, count \\ 1),
    do: %{"type" => "selection", "id" => "bank", "logic" => logic, "count" => count}

  defp expression(fact, values),
    do: %{"fact" => fact, "operator" => "contains", "value" => values}

  defp logic(condition), do: %{"conditions" => condition}
  defp never(_), do: flunk("Resolver must not be called")

  defp errors(content, resolver \\ &never/1) do
    assert {:error, issues} = Validation.validate_page_domain(content, resolver)
    issues
  end

  test "domain validation is separate from JSON Schema" do
    content = page([selection(logic(nil), 0)])

    assert :ok =
             JSONValidation.validate(
               SchemaResolver.resolve("page-content-basic.schema.json"),
               content
             )

    assert [%{code: "invalid_selection_count", path: "/model/0/count"}] = errors(content)
  end

  test "empty content, unrestricted bank, and text searches need no resolver call" do
    for content <- [
          page([]),
          page([selection(logic(nil))]),
          page([selection(logic(expression("text", "search")))])
        ] do
      assert :ok = Validation.validate_page_domain(content, &never/1)
    end
  end

  test "duplicate IDs span containers, captions, popups, trigger and extension data" do
    content =
      page([
        %{
          "type" => "group",
          "id" => "same",
          "children" => [
            %{
              "type" => "content",
              "children" => [
                %{"type" => "img", "caption" => [%{"type" => "p", "id" => "same"}]},
                %{"type" => "popup", "content" => [%{"type" => "p", "id" => "same"}]}
              ]
            }
          ]
        },
        %{"type" => "content", "custom" => %{"id" => "same"}}
      ])
      |> Map.put("trigger", %{"id" => "same"})

    assert issues = errors(content)
    assert length(issues) == 4
    assert Enum.all?(issues, &(&1.code == "duplicate_id" and &1.related_paths == ["/model/0/id"]))
    assert Enum.any?(issues, &(&1.path == "/trigger/id"))
  end

  test "integer and string logical IDs collide, resource IDs do not define logical IDs" do
    content = page([%{"id" => 1}, %{"id" => "1"}, activity(1, "placement")])

    assert [%{code: "duplicate_id", path: "/model/1/id", related_paths: ["/model/0/id"]}] =
             errors(content, fn [1] -> {:ok, %{1 => "activity"}} end)
  end

  test "collects all typed references into one distinct normalized bulk call" do
    content =
      page([
        activity("10", "a"),
        %{
          "type" => "group",
          "children" => [
            selection(
              logic(%{
                "operator" => "all",
                "children" => [expression("tags", [20, "20"]), expression("objectives", [30])]
              })
            ),
            activity(10, "b")
          ]
        },
        %{
          "type" => "content",
          "children" => [
            %{"type" => "page_link", "idref" => "40"},
            %{"type" => "img", "caption" => [%{"type" => "cite", "bibref" => 50}]}
          ]
        },
        %{"type" => "alternatives", "alternatives_id" => 60, "children" => []},
        %{"type" => "report", "activityId" => 10},
        %{
          "type" => "learning_objectives",
          "learning_objectives" => [
            %{"resource_id" => 30, "revisit_pages" => [40], "practice_pages" => [41]}
          ]
        }
      ])
      |> Map.put("bibrefs", [50])

    resolver = fn ids ->
      send(self(), {:resolved, ids})

      {:ok,
       %{
         10 => "activity",
         20 => "tag",
         30 => "objective",
         40 => "page",
         41 => "page",
         50 => "bibentry",
         60 => "alternatives"
       }}
    end

    assert :ok = Validation.validate_page_domain(content, resolver)
    assert_received {:resolved, [10, 20, 30, 40, 41, 50, 60]}
    refute_received {:resolved, _}
  end

  test "missing resources map back to each occurrence including bank operands" do
    content =
      page([activity(10, "a"), selection(logic(expression("tags", [10, 20]))), activity(10, "b")])

    issues = errors(content, fn [10, 20] -> {:ok, %{}} end)

    assert Enum.map(issues, & &1.path) == [
             "/model/0/activity_id",
             "/model/1/logic/conditions/value/0",
             "/model/1/logic/conditions/value/1",
             "/model/2/activity_id"
           ]

    assert Enum.all?(issues, &(&1.code == "missing_resource"))
  end

  test "one resolved ID can be correct for one occurrence and wrong for another" do
    content = page([activity(10, "a"), selection(logic(expression("tags", [10])))])

    assert [%{code: "resource_type_mismatch", path: "/model/1/logic/conditions/value/0"}] =
             errors(content, fn [10] -> {:ok, %{10 => "activity"}} end)
  end

  test "all count failures are independent of reference resolution" do
    for count <- [0, -1, 1.5, "1", nil] do
      content = page([selection(logic(expression("tags", [20])), count)])

      assert [%{code: "invalid_selection_count"}] =
               errors(content, fn [20] -> {:ok, %{20 => "tag"}} end)
    end
  end

  test "uses the bank parser for supported combinations and nested clauses" do
    nested = %{
      "operator" => "any",
      "children" => [
        %{"operator" => "all", "children" => [expression("tags", [20])]},
        %{"operator" => "all", "children" => [expression("objectives", [30])]}
      ]
    }

    assert :ok =
             Validation.validate_page_domain(page([selection(logic(nested))]), fn [20, 30] ->
               {:ok, %{20 => "tag", 30 => "objective"}}
             end)

    for condition <- [
          %{},
          [],
          "text",
          %{"operator" => "all", "children" => []},
          %{"fact" => "text", "operator" => "equals", "value" => "x"},
          expression("tags", [])
        ] do
      assert [%{code: "invalid_selection_logic"}] = errors(page([selection(logic(condition))]))
    end

    assert [%{code: "invalid_selection_logic"}] = errors(page([selection(%{})]))
  end

  test "rejects non-resource bank operands before querying and never resolves registration IDs" do
    for id <- [
          0,
          -1,
          2.5,
          "unrewired-export-id",
          "+1",
          " 1",
          "9223372036854775808",
          9_223_372_036_854_775_808
        ] do
      assert [%{code: "invalid_resource_id", path: "/model/0/logic/conditions/value/0"}] =
               errors(page([selection(logic(expression("tags", [id])))]))
    end

    assert :ok =
             Validation.validate_page_domain(
               page([selection(logic(expression("type", [4])))]),
               &never/1
             )

    assert [%{code: "invalid_logic_value"}] =
             errors(page([selection(logic(expression("type", ["4"])))]))
  end

  test "resolver errors, exceptions and malformed results fail closed once" do
    content = page([activity(10, "a")])

    for result <- [
          {:error, :timeout},
          :ok,
          {:ok, []},
          {:ok, %{10 => "unknown"}},
          {:ok, %{"10" => "activity"}}
        ] do
      assert [%{code: "resource_resolution_failed", path: ""}] =
               errors(content, fn [10] -> result end)
    end

    issues = errors(content, fn _ -> raise "private database details" end)
    assert [%{code: "resource_resolution_failed"}] = issues
    refute Jason.encode!(issues) =~ "private"
  end

  test "bounded issues still collect the full reference batch" do
    content = page(Enum.map(1..2000, &activity(&1, "duplicate")))

    issues =
      errors(content, fn ids ->
        assert ids == Enum.to_list(1..2000)
        send(self(), :resolved)
        {:ok, %{}}
      end)

    assert length(issues) == 100
    assert_received :resolved
    refute_received :resolved
  end

  test "JSON Pointer paths are escaped and deterministic" do
    content = page([%{"id" => "x", "~/" => %{"id" => "x"}}])
    assert [%{path: "/model/0/~0~1/id"}] = errors(content)
    assert errors(content) == errors(content)
  end

  test "does not mutate models or follow referenced activity models" do
    content = page([activity(10, "a"), activity(10, "b")])
    copy = :erlang.term_to_binary(content)

    assert :ok =
             Validation.validate_page_domain(content, fn [10] -> {:ok, %{10 => "activity"}} end)

    assert copy == :erlang.term_to_binary(content)
  end

  test "rejects adaptive, malformed and oversized direct inputs before resolution" do
    for flag <- ["advancedAuthoring", "advancedDelivery"] do
      assert [%{code: "unsupported_page_type"}] = errors(Map.put(page([]), flag, true))
    end

    assert [%{code: "invalid_input_shape"}] = errors(%{})

    assert [%{code: "input_limit_exceeded"}] =
             errors(page([%{"text" => String.duplicate("x", 4 * 1024 * 1024)}]))

    assert {:error, [%{code: "invalid_resolver"}]} =
             Validation.validate_page_domain(page([]), nil)
  end
end
