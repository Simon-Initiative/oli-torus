defmodule Oli.Validation.ActivityDomain.Rules do
  @moduledoc false
  alias Oli.Delivery.Evaluation.Rule
  alias Oli.Math.{Match, MatchConfig}
  alias Oli.Validation.ActivityDomain.Issue

  @max_rule_bytes 32_768
  @max_regex_bytes 8_192
  @max_responses 10_000

  @doc false
  def check(model, policy, slug) do
    parts = model["authoring"]["parts"]
    configs = config_index(model)
    count = Enum.reduce(parts, 0, fn part, acc -> acc + length(part["responses"]) end)

    case count > @max_responses do
      true ->
        [
          Issue.new(
            "input_limit_exceeded",
            ["parts", "authoring"],
            "Activity has too many responses"
          )
        ]

      false ->
        parts
        |> Enum.with_index()
        |> Enum.reduce({[], %{}}, fn {part, pi}, {issues, memo} ->
          path = ["responses", pi, "parts", "authoring"]

          {context_token, item_config} =
            case configs do
              {:root, config} -> {:root, config}
              {:parts, configs} -> Map.get(configs, part["id"], {:none, nil})
            end

          {issues, memo, last} =
            part["responses"]
            |> Enum.with_index()
            |> Enum.reduce({issues, memo, :empty}, fn {response, ri}, {errors, cache, _} ->
              {result, cache} =
                inspect_response(
                  response,
                  item_config,
                  cache,
                  slug == "oli_response_multi",
                  context_token
                )

              response_path = [ri | path]

              errors =
                Enum.reduce(result.errors, errors, fn {code, field, message}, acc ->
                  case length(acc) < 100 do
                    true -> [Issue.new(code, [field | response_path], message) | acc]
                    false -> acc
                  end
                end)

              {errors, cache, result.matcher}
            end)

          required =
            policy == :responses and Map.get(part, "gradingApproach", "automatic") != "manual"

          issues =
            case {required, last, length(issues) < 100} do
              {true, matcher, true} when matcher in [:empty, :conditional] ->
                [
                  Issue.new(
                    "missing_terminal_catch_all",
                    path,
                    "Automatic response matching requires a final catch-all response"
                  )
                  | issues
                ]

              _ ->
                issues
            end

          {issues, memo}
        end)
        |> elem(0)
        |> Enum.reverse()
    end
  end

  defp inspect_response(response, item_config, memo, allow_refs, context_token) do
    # Supplied nonempty legacy strings must remain syntactically valid even when
    # the structured matcher takes precedence at delivery time.
    {rule_result, memo} =
      case response do
        %{"rule" => rule} when is_binary(rule) and rule != "" ->
          cached({:rule, rule}, memo, fn -> parse_rule(rule) end)

        %{"matchConfig" => config} when is_map(config) ->
          {{:ok, nil}, memo}

        _ ->
          {{:error, "invalid_rule",
            "Response requires a parsable rule or structured match configuration"}, memo}
      end

    errors =
      case rule_result do
        {:error, code, message} -> [{code, "rule", message}]
        _ -> []
      end

    {matcher, errors, memo} =
      case Map.fetch(response, "matchConfig") do
        {:ok, config} ->
          {result, memo} =
            cached({:config, context_token, config}, memo, fn ->
              decode_config(config, item_config)
            end)

          case result do
            {:ok, always} ->
              {case always do
                 true -> :always
                 false -> :conditional
               end, errors, memo}

            {:error, code, message} ->
              {:invalid, [{code, "matchConfig", message} | errors], memo}
          end

        :error ->
          case rule_result do
            {:ok, tree} ->
              {case always?(tree, allow_refs) do
                 true -> :always
                 false -> :conditional
               end, errors, memo}

            _ ->
              {:invalid, errors, memo}
          end
      end

    {%{matcher: matcher, errors: errors}, memo}
  end

  defp cached(key, memo, fun) do
    case Map.fetch(memo, key) do
      {:ok, result} ->
        {result, memo}

      :error ->
        result = fun.()
        {result, Map.put(memo, key, result)}
    end
  end

  defp parse_rule(rule) when byte_size(rule) > @max_rule_bytes,
    do: {:error, "input_limit_exceeded", "Response rule exceeds the length limit"}

  defp parse_rule(rule) do
    with {:ok, tree} <- safe_parse(rule),
         :ok <- regexes(tree) do
      {:ok, tree}
    else
      {:error, code, message} -> {:error, code, message}
      {:error, _} -> {:error, "invalid_rule", "Rule could not be parsed completely"}
    end
  end

  # NimbleParsec callbacks can raise for input-triggered reduction shapes (for
  # example, unnested three-clause chains). Never let those escape an MCP request.
  defp safe_parse(rule) do
    Rule.parse(rule)
  rescue
    _ in [CaseClauseError, FunctionClauseError, ArgumentError] -> {:error, :invalid_rule}
  end

  defp regexes({:like, _, pattern}) when is_binary(pattern) do
    cond do
      byte_size(pattern) > @max_regex_bytes ->
        {:error, "input_limit_exceeded", "Regex exceeds the length limit"}

      String.contains?(pattern, "@@") ->
        :ok

      true ->
        case Regex.compile(pattern) do
          {:ok, _} ->
            :ok

          {:error, _} ->
            {:error, "invalid_regex", "Rule contains an invalid literal regular expression"}
        end
    end
  end

  defp regexes({op, left, right}) when op in [:&&, :||],
    do: with(:ok <- regexes(left), do: regexes(right))

  defp regexes({:!, inner}), do: regexes(inner)
  defp regexes(_), do: :ok

  defp always?({:like, :input, ".*"}, _), do: true
  defp always?({:like, {:input, _}, ".*"}, true), do: true

  defp always?({op, left, right}, allow_refs) when op in [:&&, :||],
    do: always?(left, allow_refs) and always?(right, allow_refs)

  defp always?(_, _), do: false

  defp decode_config(config, item_config) do
    effective = MatchConfig.prepare(config, item_config)

    case Match.decode_config(effective) do
      {:ok, _} ->
        {:ok, effective["type"] == "always"}

      {:error, _} ->
        {:error, "invalid_match_config",
         "Effective response match configuration could not be decoded"}
    end
  rescue
    _ in [ArgumentError, FunctionClauseError, CaseClauseError, BadMapError, Jason.EncodeError] ->
      {:error, "invalid_match_config",
       "Effective response match configuration could not be decoded"}
  end

  # Context tokens prevent every matcher cache hit from rehashing a large shared
  # item config. The last input still owns its part's effective item settings.
  defp config_index(%{"inputs" => inputs}) when is_list(inputs) do
    contexts =
      inputs
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {input, index}, acc ->
        Map.put(acc, input["partId"], {index, input["itemConfig"]})
      end)

    {:parts, contexts}
  end

  defp config_index(model), do: {:root, model["itemConfig"]}
end
