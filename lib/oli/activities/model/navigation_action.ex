defmodule Oli.Activities.Model.NavigationAction do
  defstruct [:id, :to]

  def parse(%{"id" => id, "to" => to}) do
    {:ok,
     %Oli.Activities.Model.NavigationAction{
       id: id,
       to: to
     }}
  end

  def parse(_) do
    {:error, "invalid navigation action"}
  end
end
