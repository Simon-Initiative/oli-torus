defmodule OliWeb.Delivery.StudentOnboarding.Explorations do
  use OliWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="h-full">
      <div class="flex py-6 px-[20px] hvsm:px-[70px] hvxl:px-[84px] gap-3">
        <div class="flex relative">
          <img
            src={~p"/images/assistant/dot_ai_icon.png"}
            alt="dot icon"
            class="w-24 absolute -top-4 -left-2"
          />
          <div class="w-14 shrink-0 mr-5"></div>
          <div class="flex flex-col gap-3">
            <h2 class="text-[18xl] leading-[24px] hvsm:text-[30px] hvsm:leading-[40px] hvxl:text-[40px] hvxl:leading-[54px] tracking-[0.02px] dark:text-white">
              Exploration Activities
            </h2>
            <span class="text-[14px] leading-[20px] tracking-[0.02px] dark:text-white">
              Explorations dig into how the course subject matter affects you
            </span>
          </div>
        </div>
      </div>
      <img
        class="aspect-video w-full hidden hvxl:block hvxl:h-[200px] hv2xl:h-[350px]"
        src="/images/exploration.gif"
      />
      <p class="text-[14px] leading-[20px] tracking-[0.02px] dark:text-white px-[20px] hvsm:px-[70px] hvxl:px-[84px] pt-9 pb-2">
        You will have access to both simulations and digital versions of tools used in the real world to help you explore the topics brought up in the course from a real-world perspective.
      </p>
    </div>
    """
  end
end
