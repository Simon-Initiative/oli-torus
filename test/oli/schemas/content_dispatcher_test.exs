defmodule Oli.Schemas.ContentDispatcherTest do
  use ExUnit.Case, async: true

  alias Oli.Schemas.ContentDispatcher
  alias Oli.Utils.JSONValidation

  @path "priv/schemas/v0-1-0/content-element.schema.json"

  defp schema, do: @path |> File.read!() |> Jason.decode!()

  test "checked-in dispatcher is current and generation is idempotent" do
    source = schema()
    assert ContentDispatcher.generate(source) == source
    assert source |> ContentDispatcher.generate() |> ContentDispatcher.generate() == source
  end

  test "a new declared element is selected automatically and validates its own fields" do
    source = schema()

    definition = %{
      "type" => "object",
      "properties" => %{"type" => %{"const" => "new-element"}, "value" => %{"type" => "string"}},
      "required" => ["type", "value"],
      "x-torus-dispatch" => true
    }

    modified = put_in(source, ["$defs", "new/element~"], definition)
    assert modified != ContentDispatcher.generate(modified)
    root = modified |> ContentDispatcher.generate() |> JSONValidation.build!()
    assert :ok = JSONValidation.validate(root, %{"type" => "new-element", "value" => "text"})

    assert {:error, [_ | _]} =
             JSONValidation.validate(root, %{"type" => "new-element", "value" => false})
  end

  test "structured sub-elements are excluded and ambiguous or unclassified definitions fail" do
    source = schema()
    unclassified = %{"properties" => %{"type" => %{"const" => "new-element"}}}

    assert_raise ArgumentError, ~r/must declare/, fn ->
      source |> put_in(["$defs", "new-element"], unclassified) |> ContentDispatcher.generate()
    end

    duplicate = Map.put(source["$defs"]["paragraph"], "x-torus-dispatch", true)

    assert_raise ArgumentError, ~r/exactly one/, fn ->
      source |> put_in(["$defs", "duplicate"], duplicate) |> ContentDispatcher.generate()
    end

    root = source |> ContentDispatcher.generate() |> JSONValidation.build!()

    assert {:error, [_ | _]} =
             JSONValidation.validate(root, %{"type" => "pronunciation", "children" => []})
  end

  test "context enums cannot silently reference missing dispatch targets" do
    source = put_in(schema(), ["$defs", "heading", "properties", "type", "enum"], ["missing"])

    assert_raise ArgumentError, ~r/unknown element types/, fn ->
      ContentDispatcher.generate(source)
    end
  end

  test "conditional code variants remain distinct and generation does not alter element definitions" do
    source = schema()
    generated = ContentDispatcher.generate(source)

    assert Map.delete(source["$defs"], "typed-element") ==
             Map.delete(generated["$defs"], "typed-element")

    root = JSONValidation.build!(generated)

    assert :ok =
             JSONValidation.validate(root, %{
               "type" => "code",
               "language" => "Text",
               "code" => "hello"
             })

    assert :ok =
             JSONValidation.validate(root, %{
               "type" => "code",
               "language" => "Text",
               "children" => []
             })

    assert {:error, [_ | _]} =
             JSONValidation.validate(root, %{
               "type" => "code",
               "language" => "Text",
               "code" => false,
               "children" => []
             })
  end
end
