defmodule Oli.Rendering.LTIExternalTool.Markdown do
  @moduledoc """
  Implements the Markdown writer for LTI external tools
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error
  alias Oli.Lti.PlatformInstances

  @behaviour Oli.Rendering.LTIExternalTool

  def lti_external_tool(%Context{}, %{"clientId" => client_id} = _element) do
    # TODO: Abstract this database call out of the rendering module
    platform_instance = PlatformInstances.get_platform_instance_by_client_id(client_id)

    [
      "LTI External Tool: #{platform_instance.name}\n"
    ]
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Markdown)
  end
end
