defmodule Oli.Factory do
  use ExMachina.Ecto, repo: Oli.Repo

  alias Oli.Groups.Community

  def community_factory() do
    %Community{
      name: sequence("Example Community"),
      description: "An awesome description",
      key_contact: "keycontact@example.com",
      global_access: true,
      status: :active
    }
  end
end
