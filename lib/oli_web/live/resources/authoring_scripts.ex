defmodule OliWeb.Resources.AuthoringScripts do
  use Surface.Component

  alias OliWeb.Router.Helpers, as: Routes

  @moduledoc """
  Display the title of a resource, with a breadcrumb-like header above it indicating the
  path within the curriculum to this resource.
  """

  prop scripts, :list, required: true

  def render(assigns) do
    ~F"""
    {#for script <- @scripts}
      <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}></script>
    {/for}
    """
  end
end
