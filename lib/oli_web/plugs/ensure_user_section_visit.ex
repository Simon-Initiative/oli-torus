defmodule Oli.Plugs.EnsureUserSectionVisit do
  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Delivery.Sections
  alias OliWeb.Router.Helpers, as: Routes

  @visited_sections_key "visited_sections"

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    section = conn.assigns[:section]
    is_admin = conn.assigns[:is_admin]

    cond do
      is_admin ->
        conn

      !has_visited_section_key(conn) ->
        if Sections.is_enrolled?(user.id, section.slug) do
          if Sections.has_instructor_role?(user, section.slug) do
            visited_sections =
              Map.get(get_session(conn), @visited_sections_key, %{})
              |> Map.put(section.slug, true)

            put_session(conn, @visited_sections_key, visited_sections)
          else
            if Sections.has_visited_section(section, user) do
              visited_sections =
                Map.get(get_session(conn), @visited_sections_key, %{})
                |> Map.put(section.slug, true)

              put_session(conn, @visited_sections_key, visited_sections)
            else
              redirect(conn,
                to: Routes.live_path(conn, OliWeb.Delivery.StudentOnboarding.Wizard, section.slug)
              )
              |> Plug.Conn.halt()
            end
          end
        else
          case Map.get(section, :open_and_free) and !Map.get(section, :requires_enrollment) do
            true ->
              conn
              |> redirect(to: Routes.delivery_path(conn, :show_enroll, section.slug))

            _ ->
              conn
              |> redirect(to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))
          end
          |> Plug.Conn.halt()
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
