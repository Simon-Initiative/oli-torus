defmodule Oli.Activities.Realizer.Conditions.Clause do
  @derive Jason.Encoder
  @enforce_keys [:operator, :children]
  defstruct [:operator, :children]

  alias Oli.Activities.Realizer.Conditions.Expression
  alias Oli.Activities.Realizer.Conditions.Clause

  @type t() :: %__MODULE__{
          operator: :all | :any,
          children: [%Expression{}] | [%Clause{}]
        }

  def parse(%{"operator" => "all", "children" => children}) when is_list(children),
    do: parse_with_operator(:all, children)

  def parse(%{"operator" => "any", "children" => children}) when is_list(children),
    do: parse_with_operator(:any, children)

  def parse(children) when is_list(children) do
    Enum.map(children, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid criteria clause"}
  end

  def is_clause?(candidate) do
    Map.has_key?(candidate, "children")
  end

  defp parse_with_operator(operator, children) do
    result =
      case children do
        [] ->
          {:error, "invalid clause, no child clauses or expressions"}

        [head | _] ->
          case is_clause?(head) do
            true -> Clause.parse(children)
            false -> Expression.parse(children)
          end
      end

    case result do
      {:ok, children} -> {:ok, %Clause{operator: operator, children: children}}
      e -> e
    end
  end
end
