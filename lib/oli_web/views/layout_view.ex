defmodule OliWeb.LayoutView do
  use OliWeb, :view
  use Phoenix.Component

  import Oli.Branding

  alias Oli.Accounts
  alias Oli.Authoring.Course.CreativeCommons
  alias Oli.Delivery.Paywall.AccessSummary
  alias Oli.Publishing.AuthoringResolver
  alias OliWeb.Breadcrumb.BreadcrumbTrailLive

  @non_empty_license_opts Map.keys(CreativeCommons.cc_options()) -- [:none]

  def show_pay_early(%AccessSummary{reason: :within_grace_period}), do: true
  def show_pay_early(_), do: false

  def pay_early_message(%AccessSummary{
        reason: :within_grace_period,
        grace_period_remaining: seconds_remaining
      }) do
    fractional_days_remaining = AccessSummary.as_days(seconds_remaining)

    cond do
      fractional_days_remaining < 1.0 ->
        "Today is the last day of your grace period access for this course"

      fractional_days_remaining < 2.0 ->
        "Tomorrow is the last day of your grace period for accessing this course"

      true ->
        "You have #{round(fractional_days_remaining)} days left of your grace period for accessing this course"
    end
  end

  def pay_early_message(_), do: ""

  def container_slug(assigns) do
    if assigns[:container] do
      assigns.container.slug
    else
      nil
    end
  end

  def root_container_slug(project_slug) do
    AuthoringResolver.root_container(project_slug).slug
  end

  @doc """
  Allows a delivery content template to specify any number of additional stylesheets, via URLs,
  to be included in the head portion of the document.
  """
  def additional_stylesheets(assigns) do
    Map.get(assigns, :additional_stylesheets, [])
    |> Enum.filter(fn url -> String.valid?(url) end)
    |> Enum.map(fn url -> String.trim(url, " ") end)
    |> Enum.map(&URI.encode(&1))
    |> Enum.map(fn url -> "\n<link rel=\"stylesheet\" href=\"#{url}\">" end)
    |> raw()
  end

  def active_or_nil(assigns) do
    get_in(assigns, [Access.key(:active, nil)])
  end

  def active_class(active, path) do
    if active == path do
      :active
    else
      nil
    end
  end

  def badge(badge) do
    case badge do
      nil ->
        ""

      badge ->
        content_tag(:span, badge, class: "badge badge-pill badge-primary ml-2")
    end
  end

  def sidebar_link(%{:assigns => assigns} = _conn, text, path, opts) do
    route = Keyword.get(opts, :to)
    badge = Keyword.get(opts, :badge)
    target = Keyword.get(opts, :target)

    case badge do
      nil ->
        link(text, to: route, class: active_class(active_or_nil(assigns), path), target: target)

      badge ->
        link to: route,
             class: "align-items-center #{active_class(active_or_nil(assigns), path)}",
             target: target do
          [
            content_tag(:span, text),
            content_tag(:span, badge, class: "badge badge-pill badge-primary ml-2")
          ]
        end
    end
  end

  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :inner_layout, content))
  end

  def dev_mode?() do
    Application.fetch_env!(:oli, :env) == :dev
  end

  def is_only_url?(url) do
    trimmed = String.trim(url)

    !String.contains?(trimmed, " ") and
      (String.starts_with?(trimmed, "http://") or String.starts_with?(trimmed, "https://"))
  end

  defp render_as_link(assigns) do
    ~H"""
    <.license_wrapper>
      <a href={String.trim(@custom_license_details)} , target="_blank">
        <%= String.trim(@custom_license_details) %>
      </a>
    </.license_wrapper>
    """
  end

  defp render_as_text(assigns) do
    ~H"""
    <.license_wrapper>
      <%= @custom_license_details %>
    </.license_wrapper>
    """
  end

  def render_license(%{license_type: :custom} = assigns) do
    case is_only_url?(assigns[:custom_license_details]) do
      true -> render_as_link(assigns)
      false -> render_as_text(assigns)
    end
  end

  def render_license(%{license_type: cc_license} = assigns)
      when cc_license in @non_empty_license_opts do
    cc_data = CreativeCommons.cc_options()[cc_license]

    logo_name =
      Atom.to_string(cc_license) |> String.replace("cc_", "") |> String.replace("_", "-")

    cc_text = String.split(cc_data.text, ":") |> Enum.at(1)

    assigns =
      assigns
      |> Map.put(:logo_name, logo_name)
      |> Map.put(:cc_text, cc_text)
      |> Map.put(:cc_url, cc_data.url)

    ~H"""
    <.license_wrapper>
      <div class="flex gap-2 items-center">
        <a href={@cc_url} , target="_blank">
          <img
            class="w-[100px]"
            src={~p"/images/cc_logos/#{@logo_name <> ".svg"}"}
            alt="Common Creative Logo"
          />
        </a>
        <p>
          Unless otherwise noted this work is licensed under a Creative Commons<%= @cc_text %> 4.0 Unported License.
        </p>
      </div>
    </.license_wrapper>
    """
  end

  def render_license(assigns) do
    ~H"""
    <.license_wrapper>
      <%= CreativeCommons.cc_options()[:none].text %>
    </.license_wrapper>
    """
  end

  slot(:inner_block, required: true)

  def license_wrapper(assigns) do
    ~H"""
    <div
      id="license"
      class="container mx-auto flex items-center justify-start overflow-y-hidden h-[40px] max-h-[40px] relative top-0"
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
end
