defmodule OliWeb.Delivery.StudentOnboarding.Intro do
  use Phoenix.Component

  import OliWeb.Common.SourceImage

  import OliWeb.Delivery.StudentOnboarding.Wizard,
    only: [has_required_survey: 1, has_explorations: 1]

  attr :section, :map, required: true

  def render(assigns) do
    ~H"""
    <img
      class="object-cover hidden hvxl:block hvxl:h-[150px] hv2xl:h-[300px] w-full"
      src={cover_image(@section)}
    />
    <div class="flex flex-col gap-3 px-[50px] hvsm:px-[70px] hvxl:px-[84px] py-9 dark:text-white">
      <h2 class="font-semibold text-[18xl] leading-[24px] hvsm:text-[30px] hvsm:leading-[40px] hvxl:text-[40px] hvxl:leading-[54px] tracking-[0.02px]">
        Welcome to {@section.title}!
      </h2>
      <div class="text-[14px] leading-5 tracking-[0.02px] dark:text-opacity-80">
        <p class="font-bold mb-0">Here's what to expect:</p>
        <ul class="font-normal list-disc ml-6">
          <%= if has_required_survey(@section) do %>
            <li>
              A short survey to help shape your learning experience and let your instructor get to know you
            </li>
          <% end %>
          <%= if has_explorations(@section) do %>
            <li>
              Learning about the new ‘Exploration’ activities that provide real-world examples
            </li>
          <% end %>
          <li>A personalized {@section.title} experience based on your skillsets</li>
        </ul>
      </div>
    </div>
    """
  end
end
