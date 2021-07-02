defmodule Oli.Activities.Realizer.Criteria.Expression do
  @derive Jason.Encoder
  @enforce_keys [:fact, :operator, :value]
  defstruct [:fact, :operator, :value]

  @type operators ::
          :contains | :does_not_contain | :equals | :does_not_equal | :in
  @type facts :: :objectives | :tags | :type | :text

  @type t() :: %__MODULE__{
          fact: facts(),
          operator: operators(),
          value: [integer()] | String.t()
        }

  alias Oli.Activities.Realizer.Criteria.Expression

  def parse(%{"fact" => fact, "operator" => operator, "value" => value}) when is_list(value) do
    case {fact, operator} do
      {"objectives", "contains"} ->
        {:ok, %Expression{fact: :objectives, operator: :contains, value: value}}

      {"objectives", "equals"} ->
        {:ok, %Expression{fact: :objectives, operator: :equals, value: value}}

      {"objectives", "doesNotEqual"} ->
        {:ok, %Expression{fact: :objectives, operator: :does_not_equal, value: value}}

      {"objectives", "doesNotContain"} ->
        {:ok, %Expression{fact: :objectives, operator: :does_not_contain, value: value}}

      {"tags", "contains"} ->
        {:ok, %Expression{fact: :tags, operator: :contains, value: value}}

      {"tags", "equals"} ->
        {:ok, %Expression{fact: :tags, operator: :equals, value: value}}

      {"tags", "doesNotContain"} ->
        {:ok, %Expression{fact: :tags, operator: :does_not_contain, value: value}}

      {"tags", "doesNotEqual"} ->
        {:ok, %Expression{fact: :tags, operator: :does_not_equal, value: value}}

      {"type", "contains"} ->
        {:ok, %Expression{fact: :type, operator: :contains, value: value}}

      {"type", "doesNotContain"} ->
        {:ok, %Expression{fact: :type, operator: :does_not_contain, value: value}}

      _ ->
        {:error, "invalid expression"}
    end
  end

  def parse(%{"fact" => fact, "operator" => operator, "value" => value}) do
    case {fact, operator} do
      {"text", "contains"} when is_binary(value) ->
        {:ok, %Expression{fact: :text, operator: :contains, value: value}}

      {"type", "equals"} ->
        {:ok, %Expression{fact: :type, operator: :equals, value: value}}

      {"type", "doesNotEqual"} ->
        {:ok, %Expression{fact: :type, operator: :does_not_equal, value: value}}

      _ ->
        {:error, "invalid expression"}
    end
  end

  def parse(expressions) when is_list(expressions) do
    Enum.map(expressions, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid criteria expression"}
  end
end
