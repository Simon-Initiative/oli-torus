defmodule OliWeb.LayoutView do
  use OliWeb, :view

  import OliWeb.AuthoringView,
    only: [
      author_role_text: 1,
      author_role_color: 1,
      author_icon: 1
    ]

  import Oli.Branding

  alias Oli.Accounts
  alias Oli.Publishing.AuthoringResolver
  alias OliWeb.Breadcrumb.BreadcrumbTrailLive
  alias Oli.Delivery.Paywall.AccessSummary
  alias Oli.Resources.Collaboration.CollabSpaceConfig

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
        "Tomorrow is the last day remaining in your grace period access of this course"

      true ->
        "You have #{round(fractional_days_remaining)} more days remaining in your grace period access of this course"
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

  def get_title(assigns) do
    live_title_tag(assigns[:page_title] || assigns[:title] || brand_name(),
      suffix: ""
    )
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

  def account_dropdown(%{assigns: %{current_author: current_author}} = conn),
    do:
      render(__MODULE__, "_author_account_dropdown.html",
        conn: conn,
        current_author: current_author
      )

  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :inner_layout, content))
  end

  def dev_mode?() do
    Application.fetch_env!(:oli, :env) == :dev
  end

  defp show_collab_space?(nil), do: false
  defp show_collab_space?(%CollabSpaceConfig{status: :disabled}), do: false
  defp show_collab_space?(_), do: true
end
