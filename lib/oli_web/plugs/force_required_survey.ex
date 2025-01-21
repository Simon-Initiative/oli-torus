defmodule Oli.Plugs.ForceRequiredSurvey do
  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Delivery.Sections
  alias OliWeb.Router.Helpers, as: Routes

  @completed_surveys_key "completed_section_surveys"

  @spec init(any) :: any
  def init(opts), do: opts

  def call(conn, _opts) do
    if has_required_survey?(conn) do
      if has_completed_survey?(conn) do
        conn
      else
        maybe_redirect_to_survey(conn)
      end
    else
      conn
    end
  end

  defp maybe_redirect_to_survey(conn) do
    section_slug = conn.assigns.section.slug
    user = conn.assigns[:current_user]

    # Just in time, make sure the section resource record exists
    survey_id = conn.assigns.section.required_survey_resource_id
    Oli.Delivery.Sections.Updates.ensure_section_resource_exists(section_slug, survey_id)

    has_completed_survey =
      Oli.Delivery.has_completed_survey?(section_slug, user.id) or
        Sections.is_instructor?(user, section_slug)

    if !has_completed_survey do

      %{slug: survey_slug} = Sections.get_survey(section_slug)

      # If the user is trying to access the survey, let them through
      if Map.get(conn.path_params, "revision_slug") == survey_slug do
        conn
      else
        redirect(conn,
          to: Routes.page_delivery_path(OliWeb.Endpoint, :page, section_slug, survey_slug)
        )
        |> Plug.Conn.halt()
      end
    else
      completed_surveys =
        Map.get(get_session(conn), @completed_surveys_key, %{})
        |> Map.put(section_slug, true)

      put_session(conn, @completed_surveys_key, completed_surveys)
    end
  end

  def has_required_survey?(conn) do
    with true <- !is_nil(conn.assigns[:section]),
         true <- !is_nil(conn.assigns.section.required_survey_resource_id) do
      true
    else
      _ -> false
    end
  end

  defp has_completed_survey?(conn) do
    section_slug = conn.assigns.section.slug

    case Map.get(get_session(conn), @completed_surveys_key) do
      nil -> false
      completed_section_surveys -> Map.get(completed_section_surveys, section_slug)
    end
  end
end
