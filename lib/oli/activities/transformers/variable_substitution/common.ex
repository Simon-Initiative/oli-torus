defmodule Oli.Activities.Transformers.VariableSubstitution.Common do
  @doc """
  Replace the variables found in the model with their evaluations from the evaluation
  digest.
  """
  def replace_variables(model, evaluation_digest) do
    encoded = Jason.encode!(model)

    Enum.reduce(evaluation_digest, encoded, fn %{"variable" => v} = e, s ->
      r =
        case Map.get(e, "result", "") do
          s when is_binary(s) -> s
          list when is_list(list) -> Kernel.inspect(list)
          number -> Kernel.to_string(number)
        end

      String.replace(s, "@@#{v}@@", json_escape(r))
    end)
    |> Jason.decode()
  end

  # according to RFC 4627, escape special chars in JSON
  # https://www.ietf.org/rfc/rfc4627.txt
  defp json_escape(str) do
    str
    |> String.split("")
    |> Enum.map(fn c ->
      case c do
        "\\" -> "\\\\"
        "\"" -> "\\\""
        "\b" -> "\\b"
        "\f" -> "\\f"
        "\n" -> "\\n"
        "\r" -> "\\r"
        "\t" -> "\\t"
        _ -> c
      end
    end)
    |> Enum.join()
  end
end
