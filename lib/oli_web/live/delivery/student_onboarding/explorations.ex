defmodule OliWeb.Delivery.StudentOnboarding.Explorations do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="h-full">
      <div class="flex pt-12 pb-6 px-[84px] gap-3">
        <div class="h-14 w-14 bg-gray-700 rounded-full shrink-0" />
        <div class="flex flex-col gap-3">
          <h2 class="text-[40px] leading-[54px] tracking-[0.02px] dark:text-white">
            Exploration Activities
          </h2>
          <span class="text-[14px] leading-[20px] tracking-[0.02px] dark:text-white">
            Explorations dig into how the course subject matter affects you
          </span>
        </div>
      </div>
      <img class="aspect-video w-full my-10n h-[334px]" src="/images/exploration.gif" />
      <p class="text-[14px] leading-[20px] tracking-[0.02px] dark:text-white px-[84px] py-9">
        You will have access to both simulations and digital versions of tools used in the real world to help you explore the topics brought up in the course from a real-world perspective.
      </p>
    </div>
    """
  end
end
