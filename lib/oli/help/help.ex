defmodule Oli.Help do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Help.HelpRequest

  def change_help_request(%HelpRequest{} = help_request, attrs \\ %{}) do
    HelpRequest.changeset(help_request, attrs)
  end

  def create_help_request(attrs) do
    %HelpRequest{}
    |> HelpRequest.changeset(attrs)
    |> Repo.insert()
  end
end
