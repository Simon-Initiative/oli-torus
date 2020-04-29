defmodule Oli.Delivery.Student.OverviewDesc do

  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver, as: Resolver

  defstruct [:pages, :title, :description]

  def get_overview_desc(context_id, _user) do

    with {:ok, root_resource} <- Resolver.root_resource(context_id) |> Oli.Utils.trap_nil(),
      {:ok, section} <- Sections.get_section_by(context_id: context_id) |> Oli.Utils.trap_nil()
    do
      {:ok, %Oli.Delivery.Student.OverviewDesc{
        pages: Resolver.from_resource_id(context_id, root_resource.children),
        title: section.title,
        description: section.project.description
      }}
    else
      _ -> {:error, :not_found}
    end
  end

end

