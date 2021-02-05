defmodule OliWeb.Api.PlatformInstanceView do
  use OliWeb, :view
  alias OliWeb.Api.PlatformInstanceView

  def render("index.json", %{lti_1p3_platform_instances: lti_1p3_platform_instances}) do
    %{data: render_many(lti_1p3_platform_instances, PlatformInstanceView, "platform_instance.json")}
  end

  def render("show.json", %{platform_instance: platform_instance}) do
    %{data: render_one(platform_instance, PlatformInstanceView, "platform_instance.json")}
  end

  def render("platform_instance.json", %{platform_instance: platform_instance}) do
    %{id: platform_instance.id,
      name: platform_instance.name,
      description: platform_instance.description,
      target_link_uri: platform_instance.target_link_uri,
      client_id: platform_instance.client_id,
      login_url: platform_instance.login_url,
      keyset_url: platform_instance.keyset_url,
      redirect_uris: platform_instance.redirect_uris,
      custom_params: platform_instance.custom_params}
  end
end
