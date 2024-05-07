defmodule OliWeb.Delivery.Student.DiscussionsLive do
  use OliWeb, :live_view

  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.Post
  alias Oli.Delivery.Sections
  alias OliWeb.Components.Modal
  alias OliWeb.Components.Delivery.Buttons
  alias OliWeb.Delivery.Student.Lesson.Annotations

  @default_params %{
    sort_by: "date",
    sort_order: :desc,
    filter_by: "all",
    offset: 0,
    limit: 5
  }

  def mount(_params, _session, socket) do
    if connected?(socket),
      do:
        Phoenix.PubSub.subscribe(
          Oli.PubSub,
          "collab_space_discussion_#{socket.assigns.section.slug}"
        )

    root_section_resource_resource_id =
      Sections.get_root_section_resource_resource_id(socket.assigns.section)

    {posts, more_posts_exist?} =
      get_posts(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        root_section_resource_resource_id,
        @default_params
      )

    {notes, more_notes_exist?} =
      get_notes(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        @default_params
      )

    {
      :ok,
      assign(socket,
        active_tab: :discussions,
        posts: posts,
        notes: notes,
        expanded_posts: %{},
        course_collab_space_config:
          Collaboration.get_course_collab_space_config(
            socket.assigns.section.root_section_resource_id
          ),
        post_params: @default_params,
        note_params: @default_params,
        more_posts_exist?: more_posts_exist?,
        more_notes_exist?: more_notes_exist?,
        root_section_resource_resource_id: root_section_resource_resource_id,
        posts_search_term: "",
        posts_search_results: nil,
        notes_search_term: "",
        notes_search_results: nil
      )
      |> assign_new_discussion_form()
    }
  end

  def handle_event("sort_posts", %{"sort_by" => sort_by}, socket) do
    updated_post_params =
      Map.merge(socket.assigns.post_params, %{
        sort_by: sort_by,
        sort_order:
          get_sort_order(
            socket.assigns.post_params.sort_by,
            sort_by,
            socket.assigns.post_params.sort_order
          )
      })

    {posts, more_posts_exist?} =
      get_posts(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        socket.assigns.root_section_resource_resource_id,
        updated_post_params
      )

    {:noreply,
     assign(
       socket,
       posts: posts,
       post_params: updated_post_params,
       more_posts_exist?: more_posts_exist?
     )}
  end

  def handle_event("sort_notes", %{"sort_by" => sort_by}, socket) do
    updated_note_params =
      Map.merge(socket.assigns.note_params, %{
        sort_by: sort_by,
        sort_order:
          get_sort_order(
            socket.assigns.note_params.sort_by,
            sort_by,
            socket.assigns.note_params.sort_order
          )
      })

    {notes, more_notes_exist?} =
      get_notes(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        updated_note_params
      )

    {:noreply,
     assign(
       socket,
       notes: notes,
       note_params: updated_note_params,
       more_notes_exist?: more_notes_exist?
     )}
  end

  def handle_event("reset_discussion_modal", _, socket) do
    {:noreply, assign_new_discussion_form(socket)}
  end

  def handle_event("create_new_discussion", %{"post" => attrs} = _params, socket) do
    attrs =
      Map.merge(attrs, %{
        "user_id" => socket.assigns.current_user.id,
        "section_id" => socket.assigns.section.id,
        "resource_id" => socket.assigns.root_section_resource_resource_id,
        "status" =>
          if(socket.assigns.course_collab_space_config.auto_accept,
            do: :approved,
            else: :submitted
          ),
        "visibility" => :public
      })

    case Collaboration.create_post(attrs) do
      {:ok, %Post{} = post} ->
        new_post = %Post{
          post
          | replies_count: 0,
            read_replies_count: 0,
            is_read: true,
            reaction_summaries: %{},
            replies: nil
        }

        # collab space may be configured to need approval from instructor
        if post.status == :approved,
          do:
            Phoenix.PubSub.broadcast(
              Oli.PubSub,
              "collab_space_discussion_#{socket.assigns.section.slug}",
              {:discussion_created, %Post{new_post | is_read: false}}
            )

        {:noreply,
         socket
         |> put_flash(:info, "Post successfully created")}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Couldn't create post")}
    end
  end

  def handle_event("toggle_post_replies", %{"post-id" => post_id}, socket) do
    %{current_user: current_user, posts: posts} = socket.assigns

    post_id = String.to_integer(post_id)
    post = Enum.find(posts, fn post -> post.id == post_id end)

    case post.replies do
      nil ->
        # load replies
        async_load_post_replies(current_user.id, post_id)

        {:noreply, update_post_replies(socket, post_id, :loading, fn _ -> :loading end)}

      _ ->
        # unload replies
        {:noreply, update_post_replies(socket, post_id, nil, fn _ -> nil end)}
    end
  end

  def handle_event("create_reply", %{"content" => ""}, socket) do
    {:noreply, put_flash(socket, :error, "Reply cannot be empty")}
  end

  def handle_event(
        "create_reply",
        %{"parent-post-id" => parent_post_id, "content" => value} = params,
        socket
      ) do
    %{
      current_user: current_user,
      section: section,
      course_collab_space_config: course_collab_space_config,
      root_section_resource_resource_id: root_section_resource_resource_id
    } = socket.assigns

    parent_post_id = String.to_integer(parent_post_id)

    status =
      if(course_collab_space_config.auto_accept,
        do: :approved,
        else: :submitted
      )

    attrs = %{
      status: status,
      user_id: current_user.id,
      section_id: section.id,
      resource_id: root_section_resource_resource_id,
      anonymous: params["anonymous"] == "true",
      visibility: :public,
      content: %Collaboration.PostContent{message: value},
      parent_post_id: parent_post_id,
      thread_root_id: parent_post_id
    }

    case Collaboration.create_post(attrs) do
      {:ok, post} ->
        Phoenix.PubSub.broadcast(
          Oli.PubSub,
          "collab_space_discussion_#{socket.assigns.section.slug}",
          {:reply_posted, %Collaboration.Post{post | reaction_summaries: %{}}}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Reply successfully created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create reply")}
    end
  end

  # handle toggle_reaction for reply posts
  def handle_event(
        "toggle_reaction",
        %{"parent-post-id" => parent_post_id, "post-id" => post_id, "reaction" => reaction},
        socket
      ) do
    %{current_user: current_user} = socket.assigns

    parent_post_id = String.to_integer(parent_post_id)
    post_id = String.to_integer(post_id)
    reaction = String.to_existing_atom(reaction)

    case Collaboration.toggle_reaction(post_id, current_user.id, reaction) do
      {:ok, change} ->
        {:noreply,
         update_post_replies(socket, parent_post_id, nil, fn replies ->
           Enum.map(
             replies,
             fn post ->
               if post.id == post_id do
                 %{
                   post
                   | reaction_summaries: update_reaction_summaries(post, reaction, change)
                 }
               else
                 post
               end
             end
           )
         end)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update reaction for post")}
    end
  end

  # handle toggle_reaction for root posts
  def handle_event(
        "toggle_reaction",
        %{"post-id" => post_id, "reaction" => reaction},
        socket
      ) do
    %{current_user: current_user, posts: posts} = socket.assigns

    post_id = String.to_integer(post_id)
    reaction = String.to_existing_atom(reaction)

    case Collaboration.toggle_reaction(post_id, current_user.id, reaction) do
      {:ok, change} ->
        {:noreply,
         assign(socket,
           posts:
             Enum.map(
               posts,
               fn post ->
                 if post.id == post_id do
                   %{
                     post
                     | reaction_summaries: update_reaction_summaries(post, reaction, change)
                   }
                 else
                   post
                 end
               end
             )
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update reaction for post")}
    end
  end

  def handle_event("load_more_posts", _, socket) do
    updated_post_params =
      Map.merge(socket.assigns.post_params, %{
        offset: socket.assigns.post_params.offset + socket.assigns.post_params.limit
      })

    {posts, more_posts_exist?} =
      get_posts(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        socket.assigns.root_section_resource_resource_id,
        updated_post_params
      )

    case posts do
      [] ->
        {:noreply, assign(socket, more_posts_exist?: false)}

      more_posts ->
        {:noreply,
         assign(socket,
           posts: socket.assigns.posts ++ more_posts,
           post_params: updated_post_params,
           more_posts_exist?: more_posts_exist?
         )}
    end
  end

  def handle_event("load_more_notes", _, socket) do
    updated_note_params =
      Map.merge(socket.assigns.note_params, %{
        offset: socket.assigns.note_params.offset + socket.assigns.note_params.limit
      })

    {notes, more_notes_exist?} =
      get_notes(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        updated_note_params
      )

    case notes do
      [] ->
        {:noreply, assign(socket, more_notes_exist?: false)}

      more_notes ->
        {:noreply,
         assign(socket,
           notes: socket.assigns.notes ++ more_notes,
           note_params: updated_note_params,
           more_notes_exist?: more_notes_exist?
         )}
    end
  end

  def handle_event("search_posts", %{"search_term" => ""}, socket) do
    {:noreply, assign(socket, posts_search_results: nil, posts_search_term: "")}
  end

  def handle_event("search_posts", %{"search_term" => search_term}, socket) do
    %{
      current_user: current_user,
      root_section_resource_resource_id: root_section_resource_resource_id,
      section: section
    } = socket.assigns

    async_search(
      section.id,
      current_user.id,
      root_section_resource_resource_id,
      :public,
      search_term
    )

    {:noreply, assign(socket, posts_search_results: :loading, posts_search_term: search_term)}
  end

  def handle_event("clear_search_posts", _, socket) do
    {:noreply, assign(socket, posts_search_results: nil, posts_search_term: "")}
  end

  def handle_event("search_notes", %{"search_term" => ""}, socket) do
    {:noreply, assign(socket, notes_search_results: nil, notes_search_term: "")}
  end

  def handle_event("search_notes", %{"search_term" => search_term}, socket) do
    %{
      current_user: current_user,
      root_section_resource_resource_id: root_section_resource_resource_id,
      section: section
    } = socket.assigns

    async_search(
      section.id,
      current_user.id,
      root_section_resource_resource_id,
      :private,
      search_term
    )

    {:noreply, assign(socket, notes_search_results: :loading, notes_search_term: search_term)}
  end

  def handle_event("clear_search_notes", _, socket) do
    {:noreply, assign(socket, notes_search_results: nil, notes_search_term: "")}
  end

  def handle_info({:discussion_created, _new_post}, socket)
      when socket.assigns.post_params.filter_by in ["my_activity", "page_discussions"] do
    # new broadcasted post should not be added to the UI if the user is filtering by "my activity"
    # since the new post belongs to another user and the current user has not yet interacted/replied to it.
    # The same applies to "page_discussions" since the new broadcasted posts belong to course discussions.
    {:noreply, socket}
  end

  def handle_info({:discussion_created, new_post}, socket) do
    {:noreply, assign(socket, :posts, [new_post | socket.assigns.posts])}
  end

  def handle_info({:reply_posted, new_post}, socket) do
    %{posts: posts} = socket.assigns

    {:noreply,
     assign(socket,
       posts:
         Enum.map(posts, fn post ->
           if post.id == new_post.parent_post_id do
             %Collaboration.Post{
               post
               | replies_count: post.replies_count + 1,
                 replies:
                   case post.replies do
                     nil -> [new_post]
                     replies -> replies ++ [new_post]
                   end
             }
           else
             post
           end
         end)
     )}
  end

  # handle assigns directly from async tasks
  def handle_info({ref, result}, socket) do
    Process.demonitor(ref, [:flush])

    case result do
      {:assign, assigns} ->
        {:noreply, assign(socket, assigns)}

      {:assign_post_replies, {parent_post_id, replies}} ->
        {:noreply, update_post_replies(socket, parent_post_id, replies, fn _ -> replies end)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Something went wrong")}

      _ ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <.create_discussion_modal
      course_collab_space_config={@course_collab_space_config}
      new_discussion_form={@new_discussion_form}
    />
    <.hero_banner class="bg-discussions">
      <h1 class="text-4xl md:text-6xl mb-8">Discussions</h1>
    </.hero_banner>
    <div
      id="discussions_content"
      class="overflow-x-scroll md:overflow-x-auto flex flex-col py-6 px-16 mb-10 gap-6 items-start"
    >
      <.posts_section
        posts={@posts}
        ctx={@ctx}
        section_slug={@section.slug}
        expanded_posts={@expanded_posts}
        current_user={@current_user}
        course_collab_space_config={@course_collab_space_config}
        post_params={@post_params}
        more_posts_exist?={@more_posts_exist?}
        posts_search_term={@posts_search_term}
        posts_search_results={@posts_search_results}
      />
      <.notes_section
        ctx={@ctx}
        current_user={@current_user}
        notes={@notes}
        note_params={@note_params}
        more_notes_exist?={@more_notes_exist?}
        notes_search_term={@notes_search_term}
        notes_search_results={@notes_search_results}
      />
    </div>
    """
  end

  attr :course_collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig
  attr :new_discussion_form, :map

  defp create_discussion_modal(assigns) do
    ~H"""
    <div phx-hook="TextareaListener" id="modal_wrapper">
      <Modal.modal
        :if={@course_collab_space_config && @course_collab_space_config.status == :enabled}
        class="w-1/2"
        on_cancel={JS.push("reset_discussion_modal")}
        id="new-discussion-modal"
      >
        <:title>New Discussion</:title>
        <.form
          for={@new_discussion_form}
          id="new_discussion_form"
          phx-submit={
            JS.push("create_new_discussion")
            |> Modal.hide_modal("new-discussion-modal")
            |> JS.push("reset_discussion_modal")
          }
        >
          <.inputs_for :let={post_content} field={@new_discussion_form[:content]}>
            <.input
              type="textarea"
              field={post_content[:message]}
              autocomplete="off"
              placeholder="Start a discussion..."
              data-grow="true"
              data-initial-height={44}
              onkeyup="resizeTextArea(this)"
              class="torus-input border-r-0 collab-space__textarea"
            />
          </.inputs_for>

          <div class="flex items-center justify-end">
            <.button
              phx-click={
                Modal.hide_modal("new-discussion-modal")
                |> JS.push("reset_discussion_modal")
              }
              type="button"
              class="bg-transparent text-blue-500 hover:underline hover:bg-transparent"
            >
              Cancel
            </.button>
            <%= if @course_collab_space_config.anonymous_posting do %>
              <div class="hidden">
                <.input
                  type="checkbox"
                  id="new_discussion_anonymous_checkbox"
                  field={@new_discussion_form[:anonymous]}
                />
              </div>
              <Buttons.button_with_options
                id="create_post_button"
                type="submit"
                options={[
                  %{
                    text: "Post anonymously",
                    on_click:
                      JS.dispatch("click", to: "#new_discussion_anonymous_checkbox")
                      |> JS.dispatch("click", to: "#create_post_button_button")
                  }
                ]}
              >
                Create Post
              </Buttons.button_with_options>
            <% else %>
              <Buttons.button type="submit">
                Create Post
              </Buttons.button>
            <% end %>
          </div>
        </.form>
      </Modal.modal>
    </div>
    """
  end

  attr :posts, :list
  attr :ctx, :map
  attr :section_slug, :string
  attr :expanded_posts, :map
  attr :current_user, :any
  attr :course_collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig
  attr :post_params, :map
  attr :more_posts_exist?, :boolean
  attr :posts_search_term, :string
  attr :posts_search_results, :any

  defp posts_section(assigns) do
    ~H"""
    <section id="posts" class="container mx-auto flex flex-col items-start w-full gap-6">
      <div role="posts header" class="flex justify-between items-center w-full self-stretch">
        <h3 class="text-2xl tracking-[0.02px] font-semibold dark:text-white">
          Course Discussions
        </h3>
      </div>

      <.actions
        post_params={@post_params}
        course_collab_space_config={@course_collab_space_config}
        posts_search_term={@posts_search_term}
      />

      <%= case @posts_search_results do %>
        <% nil -> %>
          <div role="posts list" class="w-full">
            <%= for post <- @posts do %>
              <div class="mb-3">
                <Annotations.post class="bg-white" post={post} current_user={@ctx.user} />
              </div>
            <% end %>
            <div :if={@posts == []} class="flex p-4 text-center w-full">
              There are no discussions to show.
            </div>
            <div class="flex w-full justify-end">
              <button
                :if={@more_posts_exist?}
                phx-click="load_more_posts"
                class="text-primary text-sm px-6 py-2 hover:text-primary/70"
              >
                Load more posts
              </button>
            </div>
          </div>
        <% :loading -> %>
          <div class="flex p-4 text-center w-full">
            Searching...
          </div>
        <% results -> %>
          <div role="search-results list" class="w-full">
            <Annotations.search_results search_results={results} current_user={@current_user} />
          </div>
      <% end %>
    </section>
    """
  end

  attr :notes, :list
  attr :ctx, :map
  attr :current_user, :any
  attr :note_params, :map
  attr :more_notes_exist?, :boolean
  attr :notes_search_term, :string
  attr :notes_search_results, :any

  defp notes_section(assigns) do
    ~H"""
    <section id="notes" class="container mx-auto flex flex-col items-start w-full gap-6">
      <div role="notes header" class="flex justify-between items-center w-full self-stretch">
        <h3 class="text-2xl tracking-[0.02px] font-semibold dark:text-white">
          Notes
        </h3>
      </div>

      <.notes_actions note_params={@note_params} notes_search_term={@notes_search_term} />

      <%= case @notes_search_results do %>
        <% nil -> %>
          <div role="notes list" class="w-full">
            <%= for post <- @notes do %>
              <div class="mb-3">
                <Annotations.post class="bg-white" post={post} current_user={@ctx.user} />
              </div>
            <% end %>
            <div :if={@notes == []} class="flex p-4 text-center w-full">
              There are no notes to show.
            </div>
            <div class="flex w-full justify-end">
              <button
                :if={@more_notes_exist?}
                phx-click="load_more_notes"
                class="text-primary text-sm px-6 py-2 hover:text-primary/70"
              >
                Load more notes
              </button>
            </div>
          </div>
        <% :loading -> %>
          <div class="flex p-4 text-center w-full">
            Searching...
          </div>
        <% results -> %>
          <div role="search-results list" class="w-full">
            <Annotations.search_results search_results={results} current_user={@current_user} />
          </div>
      <% end %>
    </section>
    """
  end

  attr :post_params, :map
  attr :course_collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig
  attr :posts_search_term, :string

  defp actions(assigns) do
    ~H"""
    <div role="posts actions" class="w-full flex gap-6">
      <div class="flex flex-1 space-x-3">
        <Annotations.search_box
          class="flex-1"
          search_term={@posts_search_term}
          on_search="search_posts"
          on_clear_search="clear_search_posts"
        />

        <.dropdown
          id="sort-dropdown"
          role="sort"
          class="inline-flex"
          button_class="rounded-[3px] py-[10px] px-6 flex justify-center items-center whitespace-nowrap text-[14px] leading-[20px] font-normal text-white bg-[#0F6CF5] hover:bg-blue-600"
          options={[
            %{
              text: "Date",
              on_click: JS.push("sort_posts", value: %{sort_by: "date"}),
              icon: sort_by_icon(@post_params.sort_by == "date", @post_params.sort_order),
              class:
                if(@post_params.sort_by == "date",
                  do: "font-bold dark:font-extrabold",
                  else: "dark:font-light"
                )
            },
            %{
              text: "Popularity",
              on_click: JS.push("sort_posts", value: %{sort_by: "popularity"}),
              icon: sort_by_icon(@post_params.sort_by == "popularity", @post_params.sort_order),
              class:
                if(@post_params.sort_by == "popularity",
                  do: "font-bold dark:font-extrabold",
                  else: "dark:font-light"
                )
            }
          ]}
        >
          <span class="text-[14px] leading-[20px] mr-2">Sort</span>
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M6.70711 8.29289C6.31658 7.90237 5.68342 7.90237 5.29289 8.29289C4.90237 8.68342 4.90237 9.31658 5.29289 9.70711L11.2929 15.7071C11.6834 16.0976 12.3166 16.0976 12.7071 15.7071L18.7071 9.70711C19.0976 9.31658 19.0976 8.68342 18.7071 8.29289C18.3166 7.90237 17.6834 7.90237 17.2929 8.29289L12 13.5858L6.70711 8.29289Z"
              fill="white"
            />
          </svg>
        </.dropdown>
      </div>

      <button
        :if={@course_collab_space_config && @course_collab_space_config.status == :enabled}
        role="new discussion"
        phx-click={Modal.show_modal("new-discussion-modal")}
        class="rounded-[3px] py-[10px] pl-[18px] pr-6 flex justify-center items-center whitespace-nowrap text-[14px] leading-[20px] font-normal text-white bg-[#0F6CF5] hover:bg-blue-600"
      >
        <svg
          role="plus icon"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class="w-6 h-6 mr-[10px]"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        New Discussion
      </button>
    </div>
    """
  end

  attr :note_params, :map
  attr :notes_search_term, :string

  defp notes_actions(assigns) do
    ~H"""
    <div role="notes actions" class="w-full flex gap-6">
      <div class="flex flex-1 space-x-3">
        <Annotations.search_box
          class="flex-1"
          search_term={@notes_search_term}
          on_search="search_notes"
          on_clear_search="clear_search_notes"
        />

        <.dropdown
          id="sort-dropdown"
          role="sort"
          class="inline-flex"
          button_class="rounded-[3px] py-[10px] px-6 flex justify-center items-center whitespace-nowrap text-[14px] leading-[20px] font-normal text-white bg-[#0F6CF5] hover:bg-blue-600"
          options={[
            %{
              text: "Date",
              on_click: JS.push("sort_notes", value: %{sort_by: "date"}),
              icon: sort_by_icon(@note_params.sort_by == "date", @note_params.sort_order),
              class:
                if(@note_params.sort_by == "date",
                  do: "font-bold dark:font-extrabold",
                  else: "dark:font-light"
                )
            }
          ]}
        >
          <span class="text-[14px] leading-[20px] mr-2">Sort</span>
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M6.70711 8.29289C6.31658 7.90237 5.68342 7.90237 5.29289 8.29289C4.90237 8.68342 4.90237 9.31658 5.29289 9.70711L11.2929 15.7071C11.6834 16.0976 12.3166 16.0976 12.7071 15.7071L18.7071 9.70711C19.0976 9.31658 19.0976 8.68342 18.7071 8.29289C18.3166 7.90237 17.6834 7.90237 17.2929 8.29289L12 13.5858L6.70711 8.29289Z"
              fill="white"
            />
          </svg>
        </.dropdown>
      </div>
    </div>
    """
  end

  defp get_posts(
         current_user_id,
         section_id,
         root_section_resource_resource_id,
         post_params
       ) do
    {posts, more_posts_exist?} =
      Collaboration.list_root_posts_for_section(
        current_user_id,
        section_id,
        root_section_resource_resource_id,
        post_params.limit,
        post_params.offset,
        post_params.sort_by,
        post_params.sort_order
      )

    {posts, more_posts_exist?}
  end

  defp get_notes(
         current_user_id,
         section_id,
         note_params
       ) do
    Collaboration.list_all_user_notes_for_section(
      current_user_id,
      section_id,
      note_params.limit,
      note_params.offset,
      note_params.sort_by,
      note_params.sort_order
    )
  end

  defp assign_new_discussion_form(socket) do
    if socket.assigns.course_collab_space_config,
      do:
        assign(socket,
          new_discussion_form: new_discussion_form()
        ),
      else: assign(socket, new_discussion_form: nil)
  end

  defp new_discussion_form() do
    to_form(Collaboration.change_post(%Post{}))
  end

  defp get_sort_order(current_sort_by, new_sort_by, sort_order)
       when current_sort_by == new_sort_by,
       do: toggle_sort_order(sort_order)

  defp get_sort_order(_current_sort_by, _new_sort_by, sort_order), do: sort_order

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(:desc), do: :asc

  defp sort_by_icon(true, :desc), do: ~s{<i class="fa-solid fa-arrow-down"></i>}
  defp sort_by_icon(true, :asc), do: ~s{<i class="fa-solid fa-arrow-up"></i>}
  defp sort_by_icon(false, _), do: nil

  defp update_post_replies(socket, post_id, default, updater) do
    %{posts: posts} = socket.assigns

    socket
    |> assign(
      posts:
        Enum.map(posts, fn post ->
          if post.id == post_id do
            Map.update(post, :replies, default, updater)
          else
            post
          end
        end)
    )
  end

  def update_reaction_summaries(post, reaction, change) do
    Map.update(
      post.reaction_summaries,
      reaction,
      %{count: 1, reacted: true},
      &%{
        count: &1.count + change,
        reacted: if(change > 0, do: true, else: false)
      }
    )
  end

  defp async_load_post_replies(user_id, post_id) do
    Task.async(fn ->
      post_replies = Collaboration.list_replies_for_post(user_id, post_id)

      {:assign_post_replies, {post_id, post_replies}}
    end)
  end

  defp async_search(
         section_id,
         current_user_id,
         root_section_resource_resource_id,
         visibility,
         search_term
       ) do
    Task.async(fn ->
      search_results =
        Collaboration.search_posts_for_user_in_point_block(
          section_id,
          if(visibility == :public, do: root_section_resource_resource_id, else: nil),
          current_user_id,
          visibility,
          nil,
          search_term
        )

      case visibility do
        :public ->
          {:assign, %{posts_search_results: search_results}}

        :private ->
          {:assign, %{notes_search_results: search_results}}
      end
    end)
  end
end
