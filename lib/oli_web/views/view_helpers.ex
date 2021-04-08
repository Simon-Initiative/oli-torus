defmodule OliWeb.ViewHelpers do
  use Phoenix.HTML

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
end
