defmodule Oli.Delivery.Student.Summary do

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts
  alias Oli.Resources.Numbering

  defstruct [:title, :description, :access_map, :hierarchy]

  def get_summary(context_id, user) do

    with {:ok, section} <- Sections.get_section_by(context_id: context_id) |> Oli.Utils.trap_nil(),
      resource_accesses <- Attempts.get_user_resource_accesses_for_context(context_id, user.id),
      [root_container_node] <- Numbering.full_hierarchy(Oli.Publishing.DeliveryResolver, context_id)
    do
      access_map = Enum.reduce(resource_accesses, %{}, fn ra, acc ->
        Map.put_new(acc, ra.resource_id, ra)
      end)

      {:ok, %Oli.Delivery.Student.Summary{
        title: section.title,
        description: section.project.description,
        access_map: access_map,
        hierarchy: root_container_node.children
      }}
    else
      _ -> {:error, :not_found}
    end
  end

end
