defmodule OliWeb.LiveSessionPlugs.SetSection do
  use OliWeb, :verified_routes

  import Phoenix.LiveView, only: [push_navigate: 2, put_flash: 3]
  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.Sections

  def on_mount(:default, %{"section_slug" => section_slug}, _session, socket) do
    case Sections.get_section_by_slug_with_base_project(section_slug) do
      nil ->
        {:halt,
         socket
         |> put_flash(:error, "Section not found")
         |> push_navigate(to: ~p"/workspaces/student")}

      section ->
        section =
          case section.required_survey_resource_id do
            nil -> Map.put(section, :required_survey, nil)
            _ -> Map.put(section, :required_survey, Sections.get_survey(section_slug))
          end

        {:cont, assign(socket, section: section, license: get_license_from_section(section))}
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, section: nil)}
  end

  defp get_license_from_section(section) do
    case section do
      %{base_project: %{attributes: %{license: %{license_type: license_type} = license}}}
      when license_type != :none and license_type != nil ->
        Map.from_struct(license)

      _ ->
        nil
    end
  end
end
