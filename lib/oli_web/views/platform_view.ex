defmodule OliWeb.PlatformView do
  use OliWeb, :view
  alias OliWeb.PlatformView

  def render("index.json", %{lti_1p3_platforms: lti_1p3_platforms}) do
    %{data: render_many(lti_1p3_platforms, PlatformView, "platform.json")}
  end

  def render("show.json", %{platform: platform}) do
    %{data: render_one(platform, PlatformView, "platform.json")}
  end

  def render("platform.json", %{platform: platform}) do
    %{id: platform.id,
      name: platform.name,
      description: platform.description,
      target_link_uri: platform.target_link_uri,
      client_id: platform.client_id,
      login_url: platform.login_url,
      keyset_url: platform.keyset_url,
      redirect_uris: platform.redirect_uris,
      custom_params: platform.custom_params}
  end
end
