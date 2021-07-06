defmodule Oli.Activities.Realizer.QueryBuilder do
  alias Oli.Activities.Realizer.Conditions
  alias Oli.Activities.Realizer.Conditions.Expression
  alias Oli.Activities.Realizer.Conditions.Clause

  def build_query(%Conditions{conditions: conditions}) do
  end

  defp build(%Clause{operator: operator, children: children}) do
  end

  defp build(%Expression{fact: "tags", operator: operator, value: value}) do
    case operator do
      :contains -> ["tags @> ARRAY[" <> Enum.join(value, ",") <> "]"]
      :does_not_contain -> ["NOT tags @> ARRAY[" <> Enum.join(value, ",") <> "]"]
      :equals -> ["tags = ARRAY[" <> Enum.join(value, ",") <> "]"]
      :does_not_equal -> ["NOT tags = ARRAY[" <> Enum.join(value, ",") <> "]"]
    end
  end

  defp build(%Expression{fact: "objectives", operator: operator, value: value}) do
    case operator do
      :contains -> ["tags @> ARRAY[" <> Enum.join(value, ",") <> "]"]
      :does_not_contain -> ["NOT tags @> ARRAY[" <> Enum.join(value, ",") <> "]"]
      :equals -> ["tags = ARRAY[" <> Enum.join(value, ",") <> "]"]
      :does_not_equal -> ["NOT tags = ARRAY[" <> Enum.join(value, ",") <> "]"]
    end
  end

  defp build(%Expression{fact: "text", operator: operator, value: value}) do
  end

  defp build(%Expression{fact: "type", operator: operator, value: value}) do
    case operator do
      :contains -> ["activity_type_id in (" <> Enum.join(value, ",") <> ")"]
      :does_not_contain -> ["NOT activity_type_id @> (" <> Enum.join(value, ",") <> ")"]
      :equals -> ["activity_type_id = #{value}"]
      :does_not_equal -> ["activity_type_id != #{value}"]
    end
  end
end
