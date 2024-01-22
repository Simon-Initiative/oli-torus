defmodule OliWeb.Components.Delivery.Dialogue do
  use OliWeb, :html

  attr :index, :integer
  attr :content, :string
  attr :user, :any

  def chat_message(assigns) do
    ~H"""
    <div class="flex gap-1.5 w-full">
      <div class="flex-col justify-start items-start flex">
        <div
          :if={is_assistant?(@user)}
          class="-mt-1.5 w-11 h-11 rounded-full justify-center items-center flex"
        >
          <div class="w-12 h-12 bg-[url('/images/assistant/footer_dot_ai.png')] bg-cover bg-center">
          </div>
        </div>
        <div
          :if={!is_assistant?(@user)}
          class="w-7 h-7 ml-2 mr-2 rounded-full justify-center items-center flex text-white bg-[#2080F0] dark:bg-[#DF8028]"
        >
          <div class="text-[14px] uppercase">
            <%= to_initials(@user) %>
          </div>
        </div>
      </div>
      <div class={[
        "grow shrink basis-0 p-3 rounded-xl shadow justify-start items-start gap-6 flex bg-opacity-30 dark:bg-opacity-100",
        if(is_assistant?(@user),
          do: "bg-gray-300 dark:bg-gray-600",
          else: "bg-gray-800 dark:bg-gray-800"
        )
      ]}>
        <div class="grow shrink basis-0 p-2 flex-col justify-start items-start gap-6 inline-flex">
          <div class="self-stretch justify-start items-start gap-3 inline-flex">
            <div class="grow shrink basis-0 self-stretch flex-col justify-start items-start gap-3 inline-flex">
              <div
                id={"message_#{@index}_content"}
                class="self-stretch dark:text-white text-sm font-normal font-['Open Sans'] tracking-tight"
              >
                <%= raw(@content) %>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="relative w-7 h-7 justify-center items-center flex">
        <div
          id={"confirmation_message_#{@index}"}
          class="absolute hidden text-xs top-6 left-1 dark:text-white"
        >
          copied!
        </div>
        <button
          :if={is_assistant?(@user)}
          class="grow shrink basis-0 self-stretch px-3 py-2 rounded-lg justify-center items-center gap-1.5 inline-flex"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 16 16"
            fill="none"
            class="cursor-pointer hover:opacity-50 dark:text-white"
            phx-hook="CopyListener"
            id={"copy_button_#{@index}"}
            data-clipboard-target={"#message_#{@index}_content"}
            data-confirmation-message-target={"#confirmation_message_#{@index}"}
            role="copy button"
          >
            <path
              d="M11.667 5.99984H12.0003C12.7367 5.99984 13.3337 6.59679 13.3337 7.33317V11.9998C13.3337 12.7362 12.7367 13.3332 12.0003 13.3332H7.33366C6.59728 13.3332 6.00033 12.7362 6.00033 11.9998V11.6665M4.00033 9.99984H8.66699C9.40337 9.99984 10.0003 9.40288 10.0003 8.6665V3.99984C10.0003 3.26346 9.40337 2.6665 8.66699 2.6665H4.00033C3.26395 2.6665 2.66699 3.26346 2.66699 3.99984V8.6665C2.66699 9.40288 3.26395 9.99984 4.00033 9.99984Z"
              class="dark:stroke-white stroke-zinc-800"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  defp is_assistant?(user) do
    user == :assistant
  end

  defp to_initials(:assistant), do: "BOT AI"

  defp to_initials(%{name: nil}), do: "?"

  defp to_initials(%{name: name}) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.slice(&1, 0..0))
    |> Enum.join()
  end
end
