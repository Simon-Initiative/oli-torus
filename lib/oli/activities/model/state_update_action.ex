defmodule Oli.Activities.Model.StateUpdateAction do
  defstruct [:id, :update]

  def parse(%{"id" => id, "update" => update}) do
    {:ok,
     %Oli.Activities.Model.StateUpdateAction{
       id: id,
       update: update
     }}
  end

  def parse(_) do
    {:error, "invalid state update action"}
  end
end
