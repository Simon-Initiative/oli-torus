defmodule OliWeb.ViewHelpers do
  use Phoenix.HTML

  import Oli.Branding

  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.PlatformRoles
  alias Oli.Delivery.Sections.Section

  def brand_logo_html(conn) do
    section = conn.assigns[:section]
    ~E"""
      <img src="<%= brand_logo_url(section) %>" height="40" class="d-dark-none d-inline-block align-top mr-2" alt="<%= brand_name(section) %>">
      <img src="<%= brand_logo_url_dark(section) %>" height="40" class="d-light-none d-inline-block align-top mr-2"  alt="<%= brand_name(section) %>">
    """
  end

  def is_admin?(%{:assigns => assigns}) do
    admin_role_id = Oli.Accounts.SystemRole.role_id().admin
    assigns.current_author.system_role_id == admin_role_id
  end

  def preview_mode(%{assigns: assigns} = _conn) do
    Map.get(assigns, :preview_mode, false)
  end

  @doc """
  Renders a link with text and an external icon which opens in a new tab
  """
  def external_link(text, opts \\ []) do
    link Keyword.merge([target: "_blank"], opts) do
      [text, content_tag("i", "", class: "las la-external-link-alt ml-1")]
    end
  end

  @admin_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    ContextRoles.get_role(:context_administrator)
  ]

  @instructor_roles [
    PlatformRoles.get_role(:institution_instructor),
    ContextRoles.get_role(:context_instructor)
  ]

  @student_roles [
    PlatformRoles.get_role(:institution_student),
    PlatformRoles.get_role(:institution_learner),
    ContextRoles.get_role(:context_learner)
  ]

  def user_role(section, user) do
    case section do
      %Section{open_and_free: open_and_free, slug: section_slug} ->
        cond do
          open_and_free ->
            :open_and_free

          PlatformRoles.has_roles?(user, @admin_roles, :any) ||
              ContextRoles.has_roles?(user, section_slug, @admin_roles, :any) ->
            :administrator

          PlatformRoles.has_roles?(user, @instructor_roles, :any) ||
              ContextRoles.has_roles?(user, section_slug, @instructor_roles, :any) ->
            :instructor

          PlatformRoles.has_roles?(user, @student_roles, :any) ||
              ContextRoles.has_roles?(user, section_slug, @student_roles, :any) ->
            :student

          true ->
            :other
        end

      _ ->
        cond do
          user.guest ->
            :open_and_free

          PlatformRoles.has_roles?(user, @admin_roles, :any) ->
            :administrator

          PlatformRoles.has_roles?(user, @instructor_roles, :any) ->
            :instructor

          PlatformRoles.has_roles?(user, @student_roles, :any) ->
            :student

          true ->
            :other
        end
    end
  end

end
