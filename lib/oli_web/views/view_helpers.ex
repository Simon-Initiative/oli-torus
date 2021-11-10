defmodule OliWeb.ViewHelpers do
  use Phoenix.HTML

  import Oli.Branding
  import Oli.Utils, only: [value_or: 2]

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Branding.Brand

  def brand_logo_html(conn_or_brand, opts \\ [])

  def brand_logo_html(%Brand{name: name, logo: logo, logo_dark: logo_dark}, opts) do
    class = Keyword.get(opts, :class, "")

    ~E"""
      <img src="<%= logo %>" height="40" class="d-dark-none <%= class %>" alt="<%= name %>">
      <img src="<%= value_or(logo_dark, logo) %>" height="40" class="d-light-none <%= class %>"  alt="<%= name %>">
    """
  end

  def brand_logo_html(conn, opts) do
    class = Keyword.get(opts, :class, "")
    section = conn.assigns[:section]

    ~E"""
      <img src="<%= brand_logo_url(section) %>" height="40" class="d-dark-none <%= class %>" alt="<%= brand_name(section) %>">
      <img src="<%= brand_logo_url_dark(section) %>" height="40" class="d-light-none <%= class %>"  alt="<%= brand_name(section) %>">
    """
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

  def is_section_instructor_or_admin?(section_slug, user) do
    Sections.is_instructor?(user, section_slug) || Sections.is_admin?(user, section_slug)
  end

  def is_section_instructor?(section_slug, user) do
    Sections.is_instructor?(user, section_slug)
  end

  def is_admin?(section_slug, user) do
    Sections.is_admin?(user, section_slug)
  end

  def maybe_section_slug(conn) do
    case conn.assigns[:section] do
      %Section{slug: slug} ->
        slug

      _ ->
        ""
    end
  end

  @doc """
  Converts a datetime to a specific timezone based on a user's session. This
  session timezone information is set and updated on the timezone api call every
  time a page is loaded.
  """
  def local_datetime(conn, %DateTime{} = datetime) do
    case Plug.Conn.get_session(conn, "local_tz") do
      nil ->
        datetime

      local_tz ->
        Timex.Timezone.convert(datetime, Timex.Timezone.get(local_tz, Timex.now()))
    end
  end

  def format_datetime(%DateTime{time_zone: time_zone} = datetime) do
    # show the timezone if the datetime hasnt been converted to a local timezone
    maybe_show_timezone =
      if time_zone == Timex.Timezone.get(:utc, Timex.now()) do
        " {Zabbr}"
      else
        ""
      end

    Timex.format!(datetime, "{Mfull} {D}, {YYYY} at {h12}:{m}:{s} {AM}#{maybe_show_timezone}")
  end
end
