defmodule OliWeb.LiveSessionPlugs.SetSection do
  use OliWeb, :verified_routes

  import Phoenix.LiveView, only: [push_navigate: 2, put_flash: 3]
  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.Sections

  def on_mount(:default, %{"section_slug" => section_slug}, _session, socket) do
    IO.inspect(section_slug, label: "section_slug")

    case Sections.get_section_by_slug(section_slug) do
      nil ->
        {:halt,
         socket
         |> put_flash(:error, "Section not found")
         |> push_navigate(to: ~p"/sections")}

      section ->
        section =
          case section.required_survey_resource_id do
            nil -> Map.put(section, :required_survey, nil)
            _ -> Map.put(section, :required_survey, Sections.get_survey(section_slug))
          end

        {:cont, assign(socket, section: section)}
    end
  end

  def on_mount(:default, params, _session, socket) do
    IO.inspect(params, label: "no section_slug")

    {:cont, assign(socket, section: nil)}
  end
end
