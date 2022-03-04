defmodule OliWeb.Common.MonacoEditor do
  use OliWeb, :surface_component

  alias Oli.Utils.SchemaResolver

  prop language, :string
  prop default_value, :string
  prop width, :string
  prop height, :string
  prop validate_schema_uri, :string
  prop default_options, :map
  prop set_options, :event
  prop set_width_height, :event
  prop set_value, :event
  prop on_mount, :event
  prop on_change, :event
  prop get_value, :event

  def render(assigns) do
    ~F"""
    <div
      id={@id}
      phx-hook="MonacoEditor"
      phx-update="ignore"
      data-language={encode_attr(@language)}
      data-schema-uri={encode_attr(@validate_schema_uri)}
      data-schemas={if @validate_schema_uri, do: encode_attr(SchemaResolver.schemas())}
      data-width={encode_attr(@width)}
      data-height={encode_attr(@height)}
      data-default-value={encode_attr(@default_value)}
      data-default-options={encode_attr(@default_options)}
      data-on-mount={encode_attr(@on_mount)}
      data-on-change={encode_attr(@on_change)}
      data-set-options={encode_attr(@set_options)}
      data-set-width-height={encode_attr(@set_width_height)}
      data-set-value={encode_attr(@set_value)}
      data-get-value={encode_attr(@get_value)}>
      <div class="text-center">
        <div class="spinner-border text-secondary" role="status">
          <span class="sr-only">Loading...</span>
        </div>
      </div>
    </div>
    """
  end

end
