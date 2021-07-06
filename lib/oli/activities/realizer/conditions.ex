defmodule Oli.Activities.Realizer.Conditions do
  @derive Jason.Encoder
  @enforce_keys [:conditions]
  defstruct [:conditions]

  @moduledoc """
  Implements a structured representation of a user specified conditions
  for realizing (aka selecting) activities from the activity bank.

  At an abstract level, the grammar implemented here is:
  <<Conditions>> := <<Clause>> || <<Expression>>
  <<Clause>> := [<<Clause>>] || [<<Expression>>]
  <<Expression>> :: Fact Operator Value

  With a <<Clause>> being of type conjunction or disjunction (all vs any)

  The client-side code represents this structure in JSON as:

  ```
  {
   conditions: {
      operator: "any",
      children: [{
        operator: "all",
        children: [{
          fact: 'tags',
          operator: 'contains',
          value: [40]
        }, {
          fact: 'objectives',
          operator: 'containsExactly',
          value: [5]
        }]
      }, {
        operator: "all"
        children: [{
          fact: 'tags',
          operator: 'doesNotContain',
          value: [48]
        }, {
          fact: 'text',
          operator: 'contains',
          value: "some text"
        }]
      }]
    }
  }
  ```

  """

  alias Oli.Activities.Realizer.Conditions.Expression
  alias Oli.Activities.Realizer.Conditions.Clause

  def parse(%{"conditions" => conditions}) do
    result =
      if Clause.is_clause?(conditions) do
        Clause.parse(conditions)
      else
        Expression.parse(conditions)
      end

    case result do
      {:ok, r} -> {:ok, %Oli.Activities.Realizer.Conditions{conditions: r}}
      e -> e
    end
  end
end
