defmodule Oli.Delivery.Student.Summary do

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts
  alias Oli.Publishing.DeliveryResolver, as: Resolver

  defstruct [:pages, :title, :description, :access_map]

  def get_summary(context_id, user) do

    with {:ok, root_container} <- Resolver.root_container(context_id) |> Oli.Utils.trap_nil(),
      {:ok, section} <- Sections.get_section_by(context_id: context_id) |> Oli.Utils.trap_nil(),
      resource_accesses <- Attempts.get_user_resource_accesses_for_context(context_id, user.id)
    do
      access_map = Enum.reduce(resource_accesses, %{}, fn ra, acc ->
        Map.put_new(acc, ra.resource_id, ra)
      end)

      {:ok, %Oli.Delivery.Student.Summary{
        pages: Resolver.from_resource_id(context_id, root_container.children),
        title: section.title,
        description: section.project.description,
        access_map: access_map
      }}
    else
      _ -> {:error, :not_found}
    end
  end

end
