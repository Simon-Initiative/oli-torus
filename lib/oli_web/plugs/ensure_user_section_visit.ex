defmodule OliWeb.Plugs.EnsureUserSectionVisit do
  use OliWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Delivery.Sections

  @visited_sections_key "visited_sections"

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    section = conn.assigns[:section]
    is_admin = conn.assigns[:is_admin]

    cond do
      is_admin ->
        # Bypass the onboarding wizard for admins
        conn

      !has_visited_section_key(conn) ->
        if Sections.has_instructor_role?(user, section.slug) do
          # Bypass the onboarding wizard for instructors by setting the section as visited
          visited_sections =
            Map.get(get_session(conn), @visited_sections_key, %{})
            |> Map.put(section.slug, true)

          put_session(conn, @visited_sections_key, visited_sections)
        else
          # If a student has already visited the section, update the visited sections map in the
          # session. Otherwise, redirect to the onboarding wizard.
          if Sections.has_visited_section(section, user) do
            visited_sections =
              Map.get(get_session(conn), @visited_sections_key, %{})
              |> Map.put(section.slug, true)

            put_session(conn, @visited_sections_key, visited_sections)
          else
            redirect(conn,
              to: ~p"/sections/#{section.slug}/welcome"
            )
            |> Plug.Conn.halt()
          end
        end

      true ->
        conn
    end
  end

  defp has_visited_section_key(conn) do
    section_slug = conn.assigns.section.slug

    case Map.get(get_session(conn), @visited_sections_key) do
      nil -> false
      completed_section_surveys -> Map.get(completed_section_surveys, section_slug)
    end
  end
end
