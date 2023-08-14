defmodule OliWeb.Common.MonacoEditor do
  use OliWeb, :html

  alias Oli.Utils.SchemaResolver

  attr(:id, :string)
  attr(:language, :string)
  attr(:default_value, :string)
  attr(:width, :string, default: "100%")
  attr(:height, :string)
  attr(:validate_schema_uri, :string)
  attr(:default_options, :map)
  attr(:set_options, :any)
  attr(:set_width_height, :any, default: nil)
  attr(:set_value, :any)
  attr(:on_mount, :any, default: nil)
  attr(:on_change, :any, default: nil)
  attr(:get_value, :any)
  attr(:use_code_lenses, :list)

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="MonacoEditor"
      phx-update="ignore"
      data-language={encode_attr(@language)}
      data-schema-uri={encode_attr(@validate_schema_uri)}
      data-schemas={if @validate_schema_uri, do: encode_attr(SchemaResolver.all())}
      data-width={encode_attr(@width)}
      data-height={encode_attr(@height)}
      data-default-value={encode_attr(@default_value)}
      data-default-options={encode_attr(@default_options)}
      data-on-mount={encode_attr(@on_mount)}
      data-on-change={encode_attr(@on_change)}
      data-set-options={encode_attr(@set_options)}
      data-set-width-height={encode_attr(@set_width_height)}
      data-set-value={encode_attr(@set_value)}
      data-get-value={encode_attr(@get_value)}
      data-use-code-lenses={if @use_code_lenses, do: encode_attr(@use_code_lenses)}
    >
      <div class="text-center">
        <div class="spinner-border text-secondary" role="status">
          <span class="sr-only">Loading...</span>
        </div>
      </div>
    </div>
    """
  end

  defp encode_attr(nil), do: nil
  defp encode_attr(data) when is_binary(data), do: Jason.encode!(%{type: "string", data: data})
  defp encode_attr(data), do: Jason.encode!(%{type: "object", data: Jason.encode!(data)})
end
