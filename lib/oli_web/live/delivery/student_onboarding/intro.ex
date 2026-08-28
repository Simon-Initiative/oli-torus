defmodule OliWeb.Delivery.StudentOnboarding.Intro do
  use Phoenix.Component

  import OliWeb.Common.SourceImage
  alias Oli.Rendering.Context
  alias OliWeb.Components.Delivery.Student

  attr :section, :map, required: true
  attr :id_prefix, :string, default: "onboarding"

  @doc """
  Renders the section-defined onboarding welcome message or the default course welcome title.
  """
  def render(assigns) do
    ~H"""
    <img
      class="object-cover hidden hvxl:block hvxl:h-[150px] hv2xl:h-[300px] w-full"
      src={cover_image(@section)}
    />
    <div class="flex flex-col gap-3 px-[50px] hvsm:px-[70px] hvxl:px-[84px] py-9 dark:text-white">
      <%= if custom_message?(@section.description) do %>
        <div
          id={"#{@id_prefix}-welcome-title"}
          role="heading"
          aria-level="2"
          class="min-w-0 max-w-full [overflow-wrap:anywhere] text-[16px] leading-6 tracking-[0.02px] [&_ol]:!pl-6 [&_ul]:!pl-6 [&>*:first-child]:font-semibold [&>*:first-child]:text-[18xl] [&>*:first-child]:leading-[24px] hvsm:[&>*:first-child]:text-[30px] hvsm:[&>*:first-child]:leading-[40px] hvxl:[&>*:first-child]:text-[40px] hvxl:[&>*:first-child]:leading-[54px]"
        >
          <Student.welcome_title
            title={@section.welcome_title}
            render_context={
              %Context{
                is_liveview: true,
                section_id: @section.id,
                section_slug: @section.slug
              }
            }
            id_prefix={@id_prefix}
          />
        </div>
        <p
          :if={custom_message?(@section.encouraging_subtitle)}
          id={"#{@id_prefix}-welcome-subtitle"}
          class="min-w-0 max-w-full [overflow-wrap:anywhere] font-semibold text-[16px] leading-6 tracking-[0.02px] dark:text-opacity-80"
        >
          {@section.encouraging_subtitle}
        </p>
        <p
          id={"#{@id_prefix}-welcome-description"}
          class="min-w-0 max-w-full whitespace-pre-line [overflow-wrap:anywhere] text-[14px] leading-5 tracking-[0.02px] dark:text-opacity-80"
        >
          {@section.description}
        </p>
      <% else %>
        <h2
          id={"#{@id_prefix}-welcome-title"}
          class="font-semibold text-[18xl] leading-[24px] hvsm:text-[30px] hvsm:leading-[40px] hvxl:text-[40px] hvxl:leading-[54px] tracking-[0.02px]"
        >
          Welcome to {@section.title}
        </h2>
      <% end %>
    </div>
    """
  end

  defp custom_message?(value) when is_binary(value), do: String.trim(value) != ""
  defp custom_message?(_value), do: false
end
