defmodule Oli.Activities.Realizer.Logic.Expression do
  @moduledoc """
  Represents a logical expression of the general form:

  <<fact>> <<operator>> <<value>>

  The supported facts are attached objectives, attached tags, activity type
  and full text.

  Four supported operators exist in two pairs: "equals", "doesNotEqual" and
  "contains", "doesNotContain".

  These operators work slightly differently depending on which fact they are applied to:

  For tags and objectives, the value must be a list for all four operators.
  Operator "contains" checks to see if the collection represented by the fact "contains"
  the list represented by the "value", even as a subset.  For instance: this expression
  "tags contains [1, 2]" would evaluate to true if "tags" was equal to [1, 2] or [1, 2, 3], but
  not if "tags" equals [1].  To represent the logic of "find activities that have either
  tag 1 or tag 2", one would use a disjunctive clause of two separate expressions.
  The "equals" operator seeks an exact match of both the value and the fact collections.

  For activity type, the "contains" operator acts like the "IN" operator from SQL, as
  it evaluates to true if the scalar value of the activity type exists within the value
  collection. The "equals" operator takes a scalar value and seeks exact equality with the
  activity type.

  The "text" fact only supports the "contains" operator which takes a scalar value and performs
  a full text search over the model of the activity.

  """

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

  alias Oli.Activities.Realizer.Logic.Expression

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
