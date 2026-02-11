defmodule OliWeb.Common.Monaco do
  use OliWeb, :html

  alias Oli.Utils.SchemaResolver

  attr(:id, :string)
  attr(:class, :string, default: nil)
  attr(:language, :string)
  attr(:default_value, :string)
  attr(:width, :string, default: "100%")
  attr(:height, :string)
  attr(:validate_schema_uri, :string, default: nil)
  attr(:default_options, :map)
  attr(:set_options, :any, default: nil)
  attr(:set_width_height, :any, default: nil)
  attr(:set_value, :any, default: nil)
  attr(:on_mount, :any, default: nil)
  attr(:on_change, :any, default: nil)
  attr(:target, :any, default: nil)
  attr(:get_value, :any, default: nil)
  attr(:use_code_lenses, :list, default: nil)
  attr(:resizable, :boolean, default: false)

  def editor(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="MonacoEditor"
      phx-update="ignore"
      class={
        if @resizable,
          do: "resize overflow-auto border border-gray-300 min-h-[400px] h-96 w-full #{@class}",
          else: @class
      }
      data-language={encode_attr(@language)}
      data-schema-uri={encode_attr(@validate_schema_uri)}
      data-schemas={if @validate_schema_uri, do: encode_attr(SchemaResolver.all())}
      data-width={encode_attr(@width)}
      data-height={encode_attr(@height)}
      data-default-value={encode_attr(@default_value)}
      data-default-options={encode_attr(@default_options)}
      data-on-mount={encode_attr(@on_mount)}
      data-on-change={encode_attr(@on_change)}
      data-target={encode_attr(@target)}
      data-set-options={encode_attr(@set_options)}
      data-set-width-height={encode_attr(@set_width_height)}
      data-set-value={encode_attr(@set_value)}
      data-get-value={encode_attr(@get_value)}
      data-use-code-lenses={if @use_code_lenses, do: encode_attr(@use_code_lenses)}
      data-resizable={encode_attr(@resizable)}
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

  defp encode_attr(%Phoenix.LiveComponent.CID{} = cid),
    do: Jason.encode!(%{type: "string", data: to_string(cid)})

  defp encode_attr(data), do: Jason.encode!(%{type: "object", data: Jason.encode!(data)})
end
