defmodule Oli.Delivery.Student.Summary do
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Repo

  defstruct [:title, :description, :access_map, :updates]

  def get_summary(section_slug, user) do
    with {:ok, section} <-
           Sections.get_section_by(slug: section_slug)
           |> Repo.preload([:base_project, :root_section_resource])
           |> Oli.Utils.trap_nil(),
         resource_accesses <-
           Attempts.get_user_resource_accesses_for_context(section.slug, user.id),
         updates <- Sections.check_for_available_publication_updates(section) do
      access_map =
        Enum.reduce(resource_accesses, %{}, fn ra, acc ->
          Map.put_new(acc, ra.resource_id, ra)
        end)

      {:ok,
       %Oli.Delivery.Student.Summary{
         title: section.title,
         description: section.base_project.description,
         access_map: access_map,
         updates: updates
       }}
    else
      _ -> {:error, :not_found}
    end
  end
end
