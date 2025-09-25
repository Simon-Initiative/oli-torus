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
          class="mt-2 w-11 h-11 rounded-full justify-center items-center flex"
        >
          <div class="w-12 h-12 bg-[url('/images/assistant/footer_dot_ai.png')] bg-cover bg-center">
          </div>
        </div>
        <div
          :if={!is_assistant?(@user)}
          class="mt-2 ml-2 mr-2 w-7 h-7 rounded-full justify-center items-center flex text-white bg-[#2f3147] dark:bg-[#2f3147]"
        >
          <div class="text-[14px] uppercase">
            {to_initials(@user)}
          </div>
        </div>
      </div>
      <div class={[
        "grow shrink basis-0 p-3 rounded-xl shadow justify-start items-start gap-6 flex dark:text-white",
        if(is_assistant?(@user),
          do: "bg-[#dcdef6] dark:bg-[#494b65]",
          else: "bg-[#edeef7] dark:bg-[#2f3147]"
        )
      ]}>
        <div class="grow shrink basis-0 p-2 flex-col justify-start items-start gap-6 inline-flex">
          <div class="self-stretch justify-start items-start gap-3 inline-flex">
            <div class="grow shrink basis-0 self-stretch flex-col justify-start items-start gap-3 inline-flex">
              <div
                id={"message_#{@index}_content"}
                class="chat-message self-stretch dark:text-white text-sm font-normal font-['Open Sans'] tracking-tight"
                phx-hook="EvaluateMathJaxExpressions"
              >
                {raw(@content)}
              </div>
            </div>
          </div>
        </div>
      </div>
      <.copy_to_clipboard show={is_assistant?(@user)} index={@index} />
    </div>
    """
  end

  defp is_assistant?(user) do
    user == :assistant
  end

  defp to_initials(:assistant), do: "BOT AI"

  defp to_initials(%{name: nil}), do: "G"

  defp to_initials(%{name: name}) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.slice(&1, 0..0))
    |> Enum.join()
  end

  defp to_initials(_), do: "?"

  attr :index, :integer
  attr :name, :string
  attr :content, :string

  def function(assigns) do
    ~H"""
    <div class="flex gap-1.5 w-full">
      <div class="flex-col justify-start items-start flex">
        <div class="mt-2 w-7 h-7 ml-2 mr-2 justify-center items-center flex dark:text-white">
          <div class="text-[14px] text-italic">
            <.function_icon />
          </div>
        </div>
      </div>
      <div class="grow shrink basis-0 px-3 py-1 rounded-xl shadow justify-start items-start gap-6 flex ">
        <div class="grow shrink basis-0 p-2 flex-col justify-start items-start gap-6 inline-flex">
          <div class="self-stretch justify-start items-start gap-3 inline-flex">
            <div class="grow shrink basis-0 self-stretch flex-col justify-start items-start gap-3 inline-flex">
              <div class="self-stretch dark:text-white text-sm font-normal font-mono tracking-tight">
                <div class="font-bold border-b border-white mb-1">
                  &gt; {@name}
                </div>
                <div id={"message_#{@index}_content"}>
                  {@content}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <.copy_to_clipboard index={@index} />
    </div>
    """
  end

  attr :index, :integer
  attr :show, :boolean, default: true

  defp copy_to_clipboard(assigns) do
    ~H"""
    <div class="relative w-7 h-7 justify-center items-center flex">
      <div
        id={"confirmation_message_#{@index}"}
        class="absolute hidden text-xs top-6 left-1 dark:text-white"
      >
        copied!
      </div>
      <button
        :if={@show}
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
    """
  end

  defp function_icon(assigns) do
    ~H"""
    <svg
      viewBox="0 0 20.000002 13.079804"
      version="1.1"
      id="svg8"
      width="20.000002"
      height="13.079803"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:svg="http://www.w3.org/2000/svg"
    >
      <defs id="defs12" />
      <path
        d="m 20.000001,7.4677111 c 0,0.8507438 -0.0696,1.657015 -0.208819,2.4188175 -0.139213,0.7579354 -0.319028,1.4095244 -0.539448,1.9547754 -0.139214,0.340297 -0.27649,0.593585 -0.411838,0.759868 -0.135346,0.166284 -0.315161,0.249424 -0.539449,0.249424 -0.235888,0 -0.433106,-0.0696 -0.591652,-0.208819 -0.154679,-0.139213 -0.232022,-0.322896 -0.232022,-0.55105 0,-0.05027 0.058,-0.259088 0.174016,-0.626456 0.116012,-0.363498 0.222353,-0.721198 0.319028,-1.073098 0.09667,-0.3519 0.185615,-0.7811344 0.266823,-1.2877169 0.08121,-0.5065812 0.121812,-1.0518275 0.121812,-1.635745 0,-0.6999294 -0.06187,-1.3611906 -0.185616,-1.9837794 C 18.049086,4.8574754 17.902147,4.2735578 17.731996,3.7321752 17.561845,3.1907927 17.47677,2.8969001 17.47677,2.8504976 c 0,-0.2281551 0.07734,-0.4099038 0.232022,-0.5452501 0.154683,-0.1353462 0.3519,-0.2030175 0.591653,-0.2030175 0.228155,0 0.409904,0.083138 0.54525,0.24942 0.135342,0.1624125 0.270689,0.4157039 0.406036,0.7598689 0.22042,0.5375163 0.400235,1.1871714 0.539449,1.948974 0.139214,0.7618038 0.208819,1.5642076 0.208819,2.4072182 z M 11.716861,9.1672649 13.294604,7.4677111 12.337517,6.435218 C 12.105495,6.187728 11.948884,6.0195142 11.867677,5.930573 11.790337,5.837761 11.730396,5.7468905 11.687861,5.6579492 c -0.04254,-0.092812 -0.0638,-0.1972163 -0.0638,-0.3132275 0,-0.2784238 0.09088,-0.5085126 0.272623,-0.6902613 0.181748,-0.1817476 0.386701,-0.2726226 0.614855,-0.2726226 0.22042,0 0.394435,0.030938 0.522048,0.092812 0.127612,0.061875 0.259087,0.1817488 0.394435,0.3596313 l 0.986086,1.2355101 0.986086,-1.2355101 c 0.143081,-0.1778825 0.27649,-0.2977601 0.400235,-0.3596313 0.12375,-0.061875 0.295826,-0.092812 0.516246,-0.092812 0.228155,0 0.433107,0.088938 0.614855,0.2668225 0.181749,0.1778813 0.272628,0.4099026 0.272628,0.6960614 0,0.1160125 -0.02127,0.22042 -0.06381,0.3132275 -0.04254,0.088938 -0.104412,0.1798163 -0.185615,0.2726238 -0.07734,0.088938 -0.232022,0.2571575 -0.46404,0.504645 l -0.957087,1.0324931 1.577742,1.6995538 c 0.100538,0.108275 0.185617,0.22622 0.255222,0.3538325 0.07348,0.12375 0.110212,0.27069 0.110212,0.440841 0,0.2822896 -0.09088,0.5104446 -0.272622,0.6844596 -0.181749,0.170146 -0.406037,0.255224 -0.672863,0.255224 -0.174015,0 -0.317095,-0.03674 -0.429239,-0.110213 -0.108275,-0.07348 -0.239756,-0.195283 -0.394435,-0.365435 L 14.41411,8.8946386 13.120596,10.425974 c -0.135348,0.154683 -0.262956,0.272624 -0.382834,0.353834 -0.119875,0.08121 -0.266823,0.121813 -0.44084,0.121813 -0.266823,0 -0.49111,-0.08507 -0.672859,-0.255224 -0.181749,-0.174015 -0.272623,-0.40217 -0.272623,-0.6844596 0,-0.16628 0.03094,-0.3074275 0.09281,-0.4234388 0.06574,-0.1160125 0.156612,-0.2397562 0.272622,-0.3712312 z M 8.8340037,7.4677111 c 0,-0.5452506 0.032875,-1.0943644 0.098612,-1.6473481 0.065738,-0.5529838 0.154683,-1.0556951 0.266823,-1.508134 0.1160125,-0.4524375 0.2436238,-0.8526776 0.3828338,-1.2007064 0.150815,-0.35963 0.290025,-0.6167888 0.4176375,-0.7714663 0.127611,-0.15855 0.305494,-0.2378226 0.533647,-0.2378226 0.243624,0 0.440842,0.067675 0.591653,0.2030176 0.150811,0.1353462 0.226221,0.317095 0.226221,0.5452501 0,0.046413 -0.08507,0.3402975 -0.255225,0.8816776 -0.170151,0.5413788 -0.317095,1.1253001 -0.44084,1.7517564 -0.12375,0.6225888 -0.185616,1.2838501 -0.185616,1.9837795 0,0.5452487 0.0406,1.0808312 0.121812,1.6067412 0.08121,0.5259113 0.170148,0.9648209 0.266823,1.3167169 0.09668,0.351896 0.203017,0.705729 0.319029,1.061497 0.116012,0.355766 0.174015,0.568449 0.174015,0.638057 0,0.228154 -0.07734,0.411837 -0.232023,0.55105 -0.154682,0.139214 -0.349966,0.208819 -0.585851,0.208819 -0.224288,0 -0.400235,-0.07927 -0.527848,-0.237822 C 9.878095,12.458092 9.7369512,12.200937 9.58227,11.841307 9.473995,11.559016 9.3753837,11.263189 9.2864437,10.953828 9.2013687,10.648334 9.1220975,10.300302 9.0486212,9.9097344 8.9790212,9.5153011 8.9248712,9.1111986 8.886205,8.6974274 c -0.0348,-0.4176375 -0.0522,-0.82754 -0.0522,-1.2297088 z"
        class="fill-[#333333] dark:fill-white"
        style="display:inline;stroke-width:0.369709"
      />
      <path
        d="M 8.290358,0.95196018 C 1.5241449,0.28060407 8.4454231,11.951728 0.92426997,12.155534"
        fill="none"
        class="stroke-[#333333] dark:stroke-white"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.84854"
        style="display:inline"
      />
      <path
        d="m 1.629936,5.5231855 c 3.0197028,0 4.7948795,0 6.0646996,0"
        fill="none"
        class="stroke-[#333333] dark:stroke-white"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.84854"
        id="path6"
        style="display:inline"
      />
    </svg>
    """
  end
end
