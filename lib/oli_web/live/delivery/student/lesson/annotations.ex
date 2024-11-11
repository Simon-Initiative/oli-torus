defmodule OliWeb.Delivery.Student.Lesson.Annotations do
  use OliWeb, :html

  import OliWeb.Icons, only: [trash: 1]

  alias Oli.Accounts.User
  alias OliWeb.Components.Common
  alias OliWeb.Components.Modal

  attr :section_slug, :string, required: true
  attr :collab_space_config, :map, required: true
  attr :create_new_annotation, :boolean, default: false
  attr :annotations, :any, required: true
  attr :current_user, Oli.Accounts.User, required: true
  attr :is_instructor, :boolean, default: false
  attr :selected_point, :any, required: true
  attr :active_tab, :atom, default: :my_notes
  attr :search_results, :any, default: nil
  attr :search_term, :string, default: ""

  def panel(assigns) do
    ~H"""
    <div id="annotations_panel" class="flex-1 flex flex-row h-[calc(100vh-170px)] overflow-hidden">
      <div class="justify-start">
        <.toggle_notes_button>
          <i class="fa-solid fa-xmark group-hover:scale-110"></i>
        </.toggle_notes_button>
      </div>
      <div class="flex-1 flex flex-col bg-white dark:bg-black p-5 rounded-bl-lg">
        <.tab_group class="py-3">
          <.tab :if={not @is_instructor} name={:my_notes} selected={@active_tab == :my_notes}>
            <.user_icon class="mr-2" /> My Notes
          </.tab>
          <.tab name={:class_notes} selected={@active_tab == :class_notes || @is_instructor}>
            <.users_icon class="mr-2" /> Class Notes
          </.tab>
        </.tab_group>
        <.search_box class="mt-2" search_term={@search_term} />
        <hr class="m-6 border-b border-b-gray-200" />
        <div class="h-[70vh] overflow-y-scroll">
          <%= case @search_results do %>
            <% nil -> %>
              <.annotations
                active_tab={@active_tab}
                annotations={@annotations}
                current_user={@current_user}
                create_new_annotation={@create_new_annotation}
                selected_point={@selected_point}
                collab_space_config={@collab_space_config}
              />
            <% _ -> %>
              <.search_results
                section_slug={@section_slug}
                search_results={@search_results}
                current_user={@current_user}
                on_reveal_post="reveal_post"
              />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :create_new_annotation, :boolean, default: false
  attr :annotations, :any, required: true
  attr :current_user, Oli.Accounts.User, required: true
  attr :selected_point, :any, required: true
  attr :active_tab, :atom, required: true
  attr :collab_space_config, :map, required: true

  defp annotations(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col gap-3 overflow-y-auto pb-[80px]">
      <.add_new_annotation_input
        :if={@selected_point}
        class="my-2"
        active={@create_new_annotation}
        disable_anonymous_option={
          @active_tab == :my_notes || is_guest(@current_user) ||
            !@collab_space_config.anonymous_posting
        }
        save_label={if(@active_tab == :my_notes, do: "Save", else: "Post")}
        placeholder={
          if(@active_tab == :my_notes, do: "Add a new note...", else: "Post a new note...")
        }
      />

      <%= case @annotations do %>
        <% nil -> %>
          <Common.loading_spinner />
        <% [] -> %>
          <div class="text-center p-4 text-gray-500"><%= empty_label(@active_tab) %></div>
        <% annotations -> %>
          <%= for annotation <- annotations do %>
            <.post
              post={annotation}
              current_user={@current_user}
              disable_anonymous_option={
                @active_tab == :my_notes || is_guest(@current_user) ||
                  !@collab_space_config.anonymous_posting
              }
            />
          <% end %>
      <% end %>
    </div>
    """
  end

  attr :current_user, Oli.Accounts.User, required: true
  attr :search_results, :any, default: nil
  attr :on_reveal_post, :string, default: nil
  attr :section_slug, :string, default: nil
  attr :show_go_to_post_link, :boolean, default: false

  def search_results(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col gap-3 overflow-y-auto pb-[80px]">
      <%= case @search_results do %>
        <% :loading -> %>
          <Common.loading_spinner />
        <% [] -> %>
          <div class="text-center p-4 text-gray-500">No results found</div>
        <% results -> %>
          <%= for post <- results do %>
            <div
              class={["flex flex-col", if(@on_reveal_post, do: "cursor-pointer")]}
              phx-click={@on_reveal_post}
              phx-value-point-marker-id={post.annotated_block_id}
              phx-value-post-id={post.id}
            >
              <.search_result
                post={post}
                current_user={@current_user}
                go_to_post_href={
                  if(@show_go_to_post_link,
                    do: ~p"/sections/#{@section_slug}/lesson/#{post.resource_slug}"
                  )
                }
              />
            </div>
          <% end %>
      <% end %>
    </div>
    """
  end

  attr :post, Oli.Resources.Collaboration.Post, required: true
  attr :current_user, Oli.Accounts.User, required: true
  attr :is_reply, :boolean, default: false
  attr :go_to_post_href, :string, default: nil

  defp search_result(assigns) do
    ~H"""
    <div class={[
      "search-result flex flex-col bg-white border-gray-200 dark:border-gray-800 rounded",
      if(@is_reply, do: "my-2 pl-4 border-l-2", else: "p-4 border-2")
    ]}>
      <div class="flex flex-row justify-between mb-1">
        <div class="font-semibold">
          <%= post_creator(@post, @current_user) %>
        </div>
        <div class="text-sm text-gray-500">
          <%= Timex.from_now(@post.inserted_at) %>
        </div>
      </div>
      <p class="my-2">
        <%= case @post.headline["message"] do %>
          <% nil -> %>
            <%= @post.content.message %>
          <% message -> %>
            <%= raw(message) %>
        <% end %>
      </p>
      <%= case @post.replies do %>
        <% nil -> %>
        <% replies -> %>
          <div class="flex flex-col gap-2 pl-4">
            <%= for reply <- replies do %>
              <.search_result post={reply} current_user={@current_user} is_reply={true} />
            <% end %>
          </div>
      <% end %>
      <%= case @go_to_post_href do %>
        <% nil -> %>
        <% href -> %>
          <div class="flex flex-row justify-end">
            <.button variant={:link} href={href}>Go to Page</.button>
          </div>
      <% end %>
    </div>
    """
  end

  defp is_guest(%User{guest: guest}), do: guest
  defp is_guest(_), do: false

  defp empty_label(:my_notes), do: "There are no notes yet"
  defp empty_label(_), do: "There are no posts yet"

  slot :inner_block, required: true

  def toggle_notes_button(assigns) do
    ~H"""
    <button
      class="flex flex-col items-center rounded-l-lg bg-white dark:bg-black px-6 py-12 text-xl group"
      phx-click="toggle_sidebar"
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  def annotations_icon(assigns) do
    ~H"""
    <svg
      width="24"
      height="25"
      viewBox="0 0 24 25"
      xmlns="http://www.w3.org/2000/svg"
      class="group-hover:scale-110"
    >
      <path
        id="Path"
        fill="#0064ed"
        fill-rule="evenodd"
        stroke="none"
        d="M 9.51568 1.826046 C 5.766479 1.826046 2.727119 4.889919 2.727119 8.669355 C 2.727119 9.763306 2.98112 10.79484 3.432001 11.709678 C 3.53856 11.925805 3.55584 12.175646 3.48008 12.404678 L 2.330881 15.88008 L 5.81328 14.748066 C 6.03848 14.674919 6.283121 14.693466 6.494881 14.799678 C 7.40368 15.255725 8.42864 15.51266 9.51568 15.51266 C 13.264959 15.51266 16.304239 12.448791 16.304239 8.669355 C 16.304239 4.889919 13.264959 1.826046 9.51568 1.826046 Z M 0.91568 8.669355 C 0.91568 3.881369 4.76608 0 9.51568 0 C 14.26536 0 18.115759 3.881369 18.115759 8.669355 C 18.115759 13.457338 14.26536 17.338711 9.51568 17.338711 C 8.276159 17.338711 7.09592 17.073872 6.02928 16.596533 L 1.183681 18.171612 C 0.85872 18.277258 0.5024 18.189596 0.26216 17.945 C 0.021919 17.700485 -0.06144 17.340405 0.04648 17.01387 L 1.6472 12.173065 C 1.17672 11.100726 0.91568 9.914679 0.91568 8.669355 Z"
      />
      <path
        id="path1"
        fill="#0064ed"
        fill-rule="evenodd"
        stroke="none"
        d="M 23.192719 16.158226 C 23.192719 11.929112 19.79184 8.500807 15.59664 8.500807 C 11.401441 8.500807 8.000481 11.929112 8.000481 16.158226 C 8.000481 20.387257 11.401441 23.815567 15.59664 23.815567 C 16.691441 23.815567 17.733999 23.581615 18.676081 23.16 L 22.955999 24.551207 C 23.243038 24.644514 23.55776 24.567179 23.77 24.351126 C 23.982239 24.135078 24.055841 23.817099 23.96048 23.528627 L 22.54664 19.252899 C 22.962162 18.305725 23.192719 17.258146 23.192719 16.158226 Z"
      />
    </svg>
    """
  end

  slot :inner_block, required: true
  attr :rest, :global, include: ~w(class)

  defp tab_group(assigns) do
    ~H"""
    <div class={["flex flex-row", @rest[:class]]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :name, :atom, required: true
  attr :selected, :boolean, default: false
  slot :inner_block, required: true

  defp tab(assigns) do
    ~H"""
    <button
      phx-click="select_tab"
      phx-value-tab={@name}
      class={[
        "flex-1 inline-flex justify-center border-l border-t border-b first:rounded-l-lg last:rounded-r-lg last:border-r px-4 py-3 inline-flex items-center",
        if(@selected,
          do: "bg-primary border-primary text-white stroke-white font-semibold",
          else:
            "stroke-[#383A44] border-gray-400 hover:bg-gray-100 dark:border-gray-700 dark:hover:bg-gray-800"
        )
      ]}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr :rest, :global, include: ~w(class)

  defp user_icon(assigns) do
    ~H"""
    <svg
      class={@rest[:class]}
      width="20"
      height="20"
      viewBox="0 0 20 20"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M16.6666 17.5V15.8333C16.6666 14.9493 16.3154 14.1014 15.6903 13.4763C15.0652 12.8512 14.2173 12.5 13.3333 12.5H6.66659C5.78253 12.5 4.93468 12.8512 4.30956 13.4763C3.68444 14.1014 3.33325 14.9493 3.33325 15.8333V17.5"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <path
        d="M10.0001 9.16667C11.841 9.16667 13.3334 7.67428 13.3334 5.83333C13.3334 3.99238 11.841 2.5 10.0001 2.5C8.15913 2.5 6.66675 3.99238 6.66675 5.83333C6.66675 7.67428 8.15913 9.16667 10.0001 9.16667Z"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :rest, :global, include: ~w(class)

  defp users_icon(assigns) do
    ~H"""
    <svg
      class={@rest[:class]}
      width="20"
      height="20"
      viewBox="0 0 20 20"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <g clip-path="url(#clip0_270_13479)">
        <path
          d="M14.1666 17.5V15.8333C14.1666 14.9493 13.8154 14.1014 13.1903 13.4763C12.5652 12.8512 11.7173 12.5 10.8333 12.5H4.16659C3.28253 12.5 2.43468 12.8512 1.80956 13.4763C1.18444 14.1014 0.833252 14.9493 0.833252 15.8333V17.5"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <path
          d="M7.50008 9.16667C9.34103 9.16667 10.8334 7.67428 10.8334 5.83333C10.8334 3.99238 9.34103 2.5 7.50008 2.5C5.65913 2.5 4.16675 3.99238 4.16675 5.83333C4.16675 7.67428 5.65913 9.16667 7.50008 9.16667Z"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <path
          d="M19.1667 17.4991V15.8324C19.1662 15.0939 18.9204 14.3764 18.4679 13.7927C18.0154 13.209 17.3819 12.7921 16.6667 12.6074"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <path
          d="M13.3333 2.60742C14.0503 2.79101 14.6858 3.20801 15.1396 3.79268C15.5935 4.37736 15.8398 5.09645 15.8398 5.83659C15.8398 6.57673 15.5935 7.29582 15.1396 7.8805C14.6858 8.46517 14.0503 8.88217 13.3333 9.06576"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </g>
      <defs>
        <clipPath id="clip0_270_13479">
          <rect width="20" height="20" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  attr :search_term, :string, default: ""
  attr :on_search, :string, default: "search"
  attr :on_clear_search, :string, default: "clear_search"
  attr :rest, :global, include: ~w(class)

  def search_box(assigns) do
    ~H"""
    <form class={["flex flex-row", @rest[:class]]} phx-submit={@on_search}>
      <div class="flex-1 relative">
        <i class="fa-solid fa-search absolute left-4 top-4 text-gray-400 pointer-events-none text-lg">
        </i>
        <input
          type="text"
          name="search_term"
          value={@search_term}
          class="w-full border border-gray-400 dark:border-gray-700 rounded-lg px-12 py-3"
          phx-change={@on_search}
          phx-debounce="500"
        />
        <button
          :if={@search_term != ""}
          type="button"
          class="absolute right-0 top-0 bottom-0 py-3 px-4"
          phx-click={@on_clear_search}
        >
          <i class="fa-solid fa-xmark text-lg"></i>
        </button>
      </div>
    </form>
    """
  end

  attr :active, :boolean, default: false
  attr :disable_anonymous_option, :boolean, default: false
  attr :save_label, :string, default: "Save"
  attr :placeholder, :string, default: "Add a new note..."
  attr :rest, :global, include: ~w(class)

  defp add_new_annotation_input(%{active: true} = assigns) do
    ~H"""
    <div class={[
      "flex flex-row p-2 border-2 border-gray-300 dark:border-gray-700 rounded-lg",
      @rest[:class]
    ]}>
      <form class="w-full" phx-submit="create_annotation">
        <div class="flex-1 flex flex-col relative border-gray-400 dark:border-gray-700 rounded-lg p-3">
          <div class="flex-1">
            <textarea
              id="annotation_input"
              name="content"
              phx-hook="AutoSelect"
              rows="4"
              class="w-full border border-gray-400 dark:border-gray-700 dark:bg-black rounded-lg p-3"
              placeholder={@placeholder}
            />
          </div>
          <%= unless @disable_anonymous_option do %>
            <div class="flex flex-row justify-start my-2">
              <.input type="checkbox" name="anonymous" value="false" label="Stay anonymous" />
            </div>
          <% end %>
          <div class="flex flex-row-reverse justify-start gap-2 mt-3">
            <Common.button variant={:primary}>
              <%= @save_label %>
            </Common.button>
            <Common.button type="button" variant={:secondary} phx-click="cancel_create_annotation">
              Cancel
            </Common.button>
          </div>
        </div>
      </form>
    </div>
    """
  end

  defp add_new_annotation_input(assigns) do
    ~H"""
    <div class={["flex flex-row", @rest[:class]]}>
      <div class="flex-1 relative">
        <input
          type="text"
          class="w-full border border-gray-400 dark:border-gray-700 rounded-lg p-3"
          placeholder={@placeholder}
          phx-focus="begin_create_annotation"
        />
      </div>
    </div>
    """
  end

  attr :post, Oli.Resources.Collaboration.Post, required: true
  attr :current_user, Oli.Accounts.User, required: true
  attr :disable_anonymous_option, :boolean, default: false
  attr :enable_unread_badge, :boolean, default: false
  attr :go_to_post_href, :string, default: nil
  attr :rest, :global, include: ~w(class)

  def post(assigns) do
    ~H"""
    <div
      id={"post-#{@post.id}"}
      class={[
        "post flex flex-col p-4 border-2 border-gray-200 dark:border-gray-800 rounded",
        @rest[:class]
      ]}
    >
      <div class="flex flex-row justify-between mb-1" role="post header">
        <div class="flex flex-row">
          <div
            :if={@enable_unread_badge && @post.unread_replies_count > 0}
            class="w-2 h-2 my-2 mr-3 bg-primary rounded-full"
          />
          <div class="font-semibold" role="user name">
            <%= post_creator(@post, @current_user) %>
          </div>
        </div>
        <div role="posted at" class="text-sm text-gray-500">
          <%= Timex.from_now(@post.inserted_at) %>
        </div>
      </div>
      <p class="my-2" role="post content">
        <%= case @post.status do %>
          <% :deleted -> %>
            <span class="italic text-gray-500">(deleted)</span>
          <% _ -> %>
            <%= @post.content.message %>
        <% end %>
      </p>
      <.post_actions
        post={@post}
        current_user={@current_user}
        on_toggle_reaction="toggle_reaction"
        on_toggle_replies="toggle_post_replies"
        go_to_post_href={@go_to_post_href}
        has_unread_replies={@enable_unread_badge && @post.unread_replies_count > 0}
      />
      <.post_replies
        post={@post}
        current_user={@current_user}
        disable_anonymous_option={@disable_anonymous_option}
      />
    </div>
    """
  end

  defp post_creator(%{anonymous: true} = post, current_user) do
    anonymous_name = "Anonymous " <> Oli.Predefined.map_id_to_anonymous_name(post.user_id)

    if post.user_id == current_user.id do
      anonymous_name <> " (Me)"
    else
      anonymous_name
    end
  end

  defp post_creator(post, current_user) do
    if post.user_id == current_user.id do
      "Me"
    else
      case post.user do
        %User{guest: false, name: name} ->
          name

        _ ->
          "Anonymous " <> Oli.Predefined.map_id_to_anonymous_name(post.user_id)
      end
    end
  end

  attr :post, Oli.Resources.Collaboration.Post, required: true
  attr :current_user, Oli.Accounts.User, required: true
  attr :on_toggle_reaction, :string, default: nil
  attr :on_toggle_replies, :string, default: nil
  attr :go_to_post_href, :string, default: nil
  attr :has_unread_replies, :boolean, default: false

  defp post_actions(assigns) do
    case assigns.post do
      %Oli.Resources.Collaboration.Post{visibility: :public, status: :submitted} ->
        ~H"""
        <div class="text-sm italic text-gray-500 my-2">
          Submitted and pending approval
        </div>
        """

      %Oli.Resources.Collaboration.Post{
        visibility: :public,
        reaction_summaries: reaction_summaries
      }
      when not is_nil(reaction_summaries) ->
        ~H"""
        <div class="flex flex-row gap-3 my-2" role="post actions">
          <button
            :if={@on_toggle_reaction}
            class="inline-flex gap-1 text-sm text-gray-500 bold py-1 px-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
            role="reactions"
            phx-click={@on_toggle_reaction}
            phx-value-reaction={:like}
            phx-value-post-id={assigns.post.id}
            phx-value-parent-post-id={assigns.post.parent_post_id}
          >
            <%= case Map.get(@post.reaction_summaries, :like) do %>
              <% nil -> %>
                <.like_icon />
              <% %{count: count, reacted: reacted} -> %>
                <.like_icon active={reacted} /> <%= if(count > 0, do: count) %>
            <% end %>
          </button>
          <button
            :if={@on_toggle_replies}
            class={[
              "inline-flex gap-1 text-sm bold py-1 px-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700",
              if(@has_unread_replies, do: "text-primary", else: "text-gray-500")
            ]}
            role="replies"
            phx-click={@on_toggle_replies}
            phx-value-post-id={assigns.post.id}
          >
            <.replies_bubble_icon active={@has_unread_replies} />
            <%= if(@post.replies_count > 0,
              do: @post.replies_count
            ) %>
          </button>
          <div class="flex-1" />
          <%= case @go_to_post_href do %>
            <% nil -> %>
            <% href -> %>
              <.button variant={:link} href={href}>Go to Page</.button>
          <% end %>
          <%= if @current_user.id == @post.user_id do %>
            <button
              disabled={@post.status == :deleted}
              class={[
                "inline-flex gap-1 text-sm text-gray-500 bold py-1 px-2 rounded-lg",
                if(@post.status == :deleted,
                  do: "opacity-50",
                  else: "hover:bg-gray-100 dark:hover:bg-gray-700"
                )
              ]}
              phx-click={JS.push("set_delete_post_id") |> Modal.show_modal("delete_post_modal")}
              phx-value-post-id={@post.id}
              phx-value-visibility={@post.visibility}
            >
              <.trash />
            </button>
          <% end %>
        </div>
        """

      _ ->
        ~H"""
        <div class="flex flex-row gap-3 my-2 justify-end" role="post actions">
          <div class="flex-1" />

          <%= case @go_to_post_href do %>
            <% nil -> %>
            <% href -> %>
              <.button variant={:link} href={href}>Go to Page</.button>
          <% end %>
          <%= if @current_user.id == @post.user_id do %>
            <button
              disabled={@post.status == :deleted}
              class={[
                "inline-flex gap-1 text-sm text-gray-500 bold py-2 px-2 rounded-lg",
                if(@post.status == :deleted,
                  do: "opacity-50",
                  else: "hover:bg-gray-100 dark:hover:bg-gray-700"
                )
              ]}
              phx-click={JS.push("set_delete_post_id") |> Modal.show_modal("delete_post_modal")}
              phx-value-post-id={@post.id}
              phx-value-visibility={@post.visibility}
            >
              <.trash />
            </button>
          <% end %>
        </div>
        """
    end
  end

  attr :post, Oli.Resources.Collaboration.Post, required: true
  attr :current_user, Oli.Accounts.User, required: true
  attr :disable_anonymous_option, :boolean, default: false

  defp post_replies(assigns) do
    ~H"""
    <%= case @post.replies do %>
      <% nil -> %>
      <% :loading -> %>
        <Common.loading_spinner />
      <% [] -> %>
        <.add_new_reply_input
          parent_post_id={@post.id}
          disable_anonymous_option={@disable_anonymous_option}
        />
      <% replies -> %>
        <div class="flex flex-col gap-2 pl-4">
          <%= for reply <- replies do %>
            <.reply post={reply} current_user={@current_user} />
          <% end %>
        </div>
        <.add_new_reply_input
          parent_post_id={@post.id}
          disable_anonymous_option={@disable_anonymous_option}
        />
    <% end %>
    """
  end

  attr :parent_post_id, :integer, required: true
  attr :disable_anonymous_option, :boolean, default: false

  defp add_new_reply_input(assigns) do
    ~H"""
    <div class="flex flex-row mt-2">
      <form class="w-full" phx-submit="create_reply" phx-value-parent-post-id={@parent_post_id}>
        <div class="flex-1 relative">
          <textarea
            id="reply_input"
            name="content"
            phx-hook="AutoSelect"
            rows="1"
            class="w-full min-h-[50px] border border-gray-400 dark:border-gray-700 dark:bg-black rounded-lg p-3 pr-12"
            placeholder="Add a reply..."
          />
          <button class="absolute right-2 bottom-2.5 py-1 px-1.5 rounded-lg">
            <.send_icon />
          </button>
        </div>
        <%= unless @disable_anonymous_option do %>
          <div class="flex flex-row justify-start my-2">
            <.input type="checkbox" name="anonymous" value="false" label="Stay anonymous" />
          </div>
        <% end %>
      </form>
    </div>
    """
  end

  defp send_icon(assigns) do
    ~H"""
    <svg width="34" height="34" viewBox="0 0 34 34" fill="none" xmlns="http://www.w3.org/2000/svg">
      <g>
        <path
          fill-rule="evenodd"
          clip-rule="evenodd"
          d="M32.1126 16.9704C32.1126 17.2865 31.966 17.5683 31.737 17.7516C31.6728 17.8029 31.6022 17.8465 31.5265 17.881L12.4545 27.0638C12.0851 27.2417 11.6445 27.176 11.343 26.8982C11.0415 26.6203 10.9402 26.1865 11.0873 25.8038L14.4848 16.9704L11.0873 8.13703C10.9402 7.75434 11.0415 7.32057 11.343 7.0427C11.6445 6.76484 12.0851 6.69917 12.4545 6.87705L31.5265 16.0598C31.6026 16.0945 31.6737 16.1385 31.7382 16.1903C31.7856 16.2283 31.8292 16.2704 31.8686 16.3158C32.0206 16.4912 32.1126 16.7201 32.1126 16.9704ZM26.7305 15.9704L13.8595 9.77328L16.243 15.9704H26.7305ZM16.243 17.9704L26.7305 17.9704L13.8595 24.1676L16.243 17.9704Z"
          fill="#0064ED"
        />
      </g>
    </svg>
    """
  end

  attr :post, Oli.Resources.Collaboration.Post, required: true
  attr :current_user, Oli.Accounts.User, required: true

  defp reply(assigns) do
    ~H"""
    <div class="flex flex-col my-2 pl-4 border-l-2 border-gray-200 dark:border-gray-800">
      <div class="flex flex-row justify-between mb-1">
        <div class="font-semibold">
          <%= post_creator(@post, @current_user) %>
        </div>
        <div class="text-sm text-gray-500">
          <%= Timex.from_now(@post.inserted_at) %>
        </div>
      </div>
      <p class="my-2">
        <%= case @post.status do %>
          <% :deleted -> %>
            <span class="italic text-gray-500">(deleted)</span>
          <% _ -> %>
            <%= @post.content.message %>
        <% end %>
      </p>
      <.post_actions post={@post} current_user={@current_user} on_toggle_reaction="toggle_reaction" />
    </div>
    """
  end

  def delete_post_modal(assigns) do
    ~H"""
    <Modal.modal id="delete_post_modal" class="w-1/2">
      <:title>Delete Note</:title>
      <.form
        phx-submit={JS.push("delete_post") |> Modal.hide_modal("delete_post_modal")}
        for={%{}}
        class="flex flex-col gap-6"
        id="delete_post_form"
      >
        <p class="my-2">Are you sure you want to delete this note?</p>
        <div class="flex flex-row justify-end gap-2">
          <.button
            type="button"
            variant={:secondary}
            phx-click={Modal.hide_modal("delete_post_modal")}
          >
            Cancel
          </.button>
          <.button type="submit" variant={:danger}>Delete</.button>
        </div>
      </.form>
    </Modal.modal>
    """
  end

  def find_and_update_post(posts, post_id, update_fn) when is_list(posts) do
    Enum.map(posts, fn post ->
      if post.id == post_id do
        update_fn.(post)
      else
        %{post | replies: find_and_update_post(post.replies, post_id, update_fn)}
      end
    end)
  end

  def find_and_update_post(posts, _post_id, _update_fn), do: posts

  attr :point_marker, :any, required: true
  attr :selected, :boolean, default: false
  attr :count, :integer, default: nil

  def annotation_bubble(%{point_marker: :page} = assigns) do
    ~H"""
    <button
      class="absolute top-0 right-[-15px] cursor-pointer group"
      phx-click="toggle_annotation_point"
    >
      <.chat_bubble active={@selected} count={@count} />
    </button>
    """
  end

  def annotation_bubble(assigns) do
    ~H"""
    <button
      class="absolute right-[-15px] cursor-pointer group"
      style={"top: #{@point_marker.top}px"}
      phx-click="toggle_annotation_point"
      phx-value-point-marker-id={@point_marker.id}
    >
      <.chat_bubble active={@selected} count={@count} />
    </button>
    """
  end

  attr :active, :boolean, default: false
  attr :count, :integer, default: nil

  def chat_bubble(assigns) do
    ~H"""
    <svg
      width="31"
      height="31"
      viewBox="0 0 31 31"
      fill="none"
      class="group-hover:scale-110 group-active:scale-100"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M30 14.6945C30.0055 16.8209 29.5087 18.9186 28.55 20.8167C27.4132 23.0912 25.6657 25.0042 23.5031 26.3416C21.3405 27.679 18.8483 28.3879 16.3055 28.3889C14.1791 28.3944 12.0814 27.8976 10.1833 26.9389L1 30L4.06111 20.8167C3.10239 18.9186 2.60556 16.8209 2.61111 14.6945C2.61209 12.1517 3.32098 9.65951 4.65837 7.49692C5.99577 5.33433 7.90884 3.58679 10.1833 2.45004C12.0814 1.49132 14.1791 0.994502 16.3055 1.00005H17.1111C20.4692 1.18531 23.641 2.60271 26.0191 4.98087C28.3973 7.35902 29.8147 10.5308 30 13.8889V14.6945Z"
        class={[
          if(@active,
            do: "fill-primary stroke-primary",
            else: "fill-white dark:fill-gray-800 stroke-gray-300 dark:stroke-gray-700"
          )
        ]}
        stroke-width="1.61111"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <%= case @count do %>
        <% nil -> %>
          <text
            x="52%"
            y="50%"
            dominant-baseline="middle"
            text-anchor="middle"
            class={[
              "text-xl",
              if(@active, do: "fill-white", else: "fill-gray-500 dark:fill-gray-200")
            ]}
          >
            +
          </text>
        <% _ -> %>
          <text
            x="52%"
            y="50%"
            dominant-baseline="middle"
            text-anchor="middle"
            class={[
              "text-sm",
              if(@active, do: "fill-white", else: "fill-gray-500 dark:fill-gray-200")
            ]}
          >
            <%= @count %>
          </text>
      <% end %>
    </svg>
    """
  end

  attr :active, :boolean, default: false

  def replies_bubble_icon(assigns) do
    ~H"""
    <svg width="23" height="23" viewBox="0 0 23 23" fill="none" xmlns="http://www.w3.org/2000/svg">
      <line
        class={[
          if(@active,
            do: "stroke-primary",
            else: "stroke-gray-800 dark:stroke-gray-200"
          )
        ]}
        x1="6.16821"
        y1="8.60156"
        x2="16.0243"
        y2="8.60156"
        stroke-width="1.5"
      />
      <line
        class={[
          if(@active,
            do: "stroke-primary",
            else: "stroke-gray-800 dark:stroke-gray-200"
          )
        ]}
        x1="6.16821"
        y1="13.6055"
        x2="16.0243"
        y2="13.6055"
        stroke-width="1.5"
      />
      <path
        class={[
          if(@active,
            do: "fill-primary",
            else: "fill-gray-800 dark:fill-gray-200"
          )
        ]}
        fill-rule="evenodd"
        clip-rule="evenodd"
        d="M11.7869 2.27309C7.1428 2.27309 3.37805 6.03784 3.37805 10.6819C3.37805 12.0261 3.69262 13.2936 4.25113 14.4177C4.38308 14.6833 4.4045 14.9903 4.31072 15.2717L2.8872 19.5421L7.20077 18.1512C7.47968 18.0613 7.78271 18.084 8.04505 18.2146C9.17069 18.775 10.4403 19.0907 11.7869 19.0907C16.4309 19.0907 20.1957 15.3259 20.1957 10.6819C20.1957 6.03784 16.4309 2.27309 11.7869 2.27309ZM1.13425 10.6819C1.13425 4.79863 5.90359 0.0292969 11.7869 0.0292969C17.6701 0.0292969 22.4395 4.79863 22.4395 10.6819C22.4395 16.5652 17.6701 21.3345 11.7869 21.3345C10.2515 21.3345 8.78951 21.009 7.46835 20.4225L1.46623 22.3579C1.06368 22.4877 0.622338 22.38 0.324734 22.0795C0.0271304 21.779 -0.0761506 21.3366 0.0576046 20.9353L2.04039 14.9871C1.45758 13.6695 1.13425 12.2121 1.13425 10.6819Z"
      />
    </svg>
    """
  end

  attr :active, :boolean, default: false

  defp like_icon(assigns) do
    ~H"""
    <svg width="22" height="24" viewBox="0 0 22 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path
        class={[
          if(@active, do: "stroke-primary", else: "stroke-gray-800 dark:stroke-gray-200")
        ]}
        d="M6 10.6466L10 1.11719C10.7956 1.11719 11.5587 1.45185 12.1213 2.04755C12.6839 2.64326 13 3.45121 13 4.29366V8.52895H18.66C18.9499 8.52548 19.2371 8.58878 19.5016 8.71448C19.7661 8.84017 20.0016 9.02526 20.1919 9.25691C20.3821 9.48856 20.5225 9.76123 20.6033 10.056C20.6842 10.3508 20.7035 10.6607 20.66 10.9642L19.28 20.4937C19.2077 20.9986 18.9654 21.4589 18.5979 21.7897C18.2304 22.1204 17.7623 22.2994 17.28 22.2937H6M6 10.6466V22.2937M6 10.6466H3C2.46957 10.6466 1.96086 10.8697 1.58579 11.2668C1.21071 11.664 1 12.2026 1 12.7642V20.176C1 20.7376 1.21071 21.2763 1.58579 21.6734C1.96086 22.0705 2.46957 22.2937 3 22.2937H6"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end
end
