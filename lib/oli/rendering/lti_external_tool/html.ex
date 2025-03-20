defmodule Oli.Rendering.LTIExternalTool.Html do
  @moduledoc """
  Implements the Html writer for LTI external tools
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error
  alias OliWeb.Components.Delivery.LTIExternalTools
  alias Oli.Lti.PlatformInstances
  alias Lti_1p3.Platform.{LoginHint, LoginHints}

  @behaviour Oli.Rendering.LTIExternalTool

  def lti_external_tool(
        %Context{user: user, section_slug: section_slug},
        %{"id" => _element_id, "clientId" => client_id} = _element
      ) do
    # TODO: Abstract this database call out of the rendering module
    platform_instance = PlatformInstances.get_platform_instance_by_client_id(client_id)

    {:ok, %LoginHint{value: login_hint}} =
      LoginHints.create_login_hint(user.id, "section:#{section_slug}")

    launch_params = %{
      iss: Oli.Utils.get_base_url(),
      login_hint: login_hint,
      client_id: platform_instance.client_id,
      target_link_uri: platform_instance.target_link_uri
    }

    [
      ~s|<div class="lti-external-tool">|,
      LTIExternalTools.lti_external_tool(%{
        name: platform_instance.name,
        login_url: platform_instance.login_url,
        launch_params: launch_params
      })
      |> Phoenix.HTML.Safe.to_iodata(),
      ~s|</div>|
    ]
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
