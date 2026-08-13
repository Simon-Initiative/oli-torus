defmodule OliWeb.Delivery.StudentOnboarding.Intro do
  use Phoenix.Component

  import OliWeb.Common.SourceImage
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
        <h2
          id={"#{@id_prefix}-welcome-title"}
          class="font-semibold text-[18xl] leading-[24px] hvsm:text-[30px] hvsm:leading-[40px] hvxl:text-[40px] hvxl:leading-[54px] tracking-[0.02px]"
        >
          <Student.welcome_title title={@section.welcome_title} />
        </h2>
        <p
          :if={custom_message?(@section.encouraging_subtitle)}
          id={"#{@id_prefix}-welcome-subtitle"}
          class="font-semibold text-[16px] leading-6 tracking-[0.02px] dark:text-opacity-80"
        >
          {@section.encouraging_subtitle}
        </p>
        <p
          id={"#{@id_prefix}-welcome-description"}
          class="whitespace-pre-line text-[14px] leading-5 tracking-[0.02px] dark:text-opacity-80"
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
