defmodule Oli.Utils.JSONValidationTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.JSONValidation

  test "reuses built schemas across concurrent callers without casting data" do
    schema = %{
      "type" => "object",
      "properties" => %{"count" => %{"type" => "integer"}},
      "required" => ["count"]
    }

    roots =
      1..10
      |> Task.async_stream(fn _ -> JSONValidation.build!(schema) end)
      |> Enum.map(fn {:ok, root} -> root end)

    assert Enum.uniq(roots) == [JSONValidation.build!(schema)]
    assert :ok = JSONValidation.validate(hd(roots), %{"count" => 2.0})

    assert {:error, [{message, "#/count"}]} =
             JSONValidation.validate(hd(roots), %{"count" => "2"})

    assert is_binary(message)
  end

  test "preserves errors and escaped data paths through combinators" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "a/b~c" => %{"anyOf" => [%{"type" => "integer"}, %{"type" => "boolean"}]}
      }
    }

    root = JSONValidation.build!(schema)
    assert {:error, errors} = JSONValidation.validate(root, %{"a/b~c" => []})
    assert errors != []

    assert Enum.all?(errors, fn {message, path} ->
             is_binary(message) and path == "#/a~1b~0c"
           end)
  end

  test "reports oneOf ambiguity even when child schemas all succeed" do
    root = JSONValidation.build!(%{"oneOf" => [%{"type" => "number"}, %{"type" => "integer"}]})
    assert {:error, [{message, "#"}]} = JSONValidation.validate(root, 1)
    assert is_binary(message)
  end

  test "validates formats and local recursive schema references" do
    root = JSONValidation.build!(%{"type" => "string", "format" => "date-time"})
    assert :ok = JSONValidation.validate(root, "2026-11-15T12:00:00Z")
    assert {:error, [_ | _]} = JSONValidation.validate(root, "invalid")

    root = Oli.Utils.SchemaResolver.resolve("page-content-basic.schema.json")
    assert :ok = JSONValidation.validate(root, %{"version" => "0.1.0", "model" => []})
    assert {:error, [_ | _]} = JSONValidation.validate(root, %{"model" => []})
  end
end
