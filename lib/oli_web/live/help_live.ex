defmodule OliWeb.HelpLive do
  use OliWeb, :live_view

  alias Oli.Help.HelpRequest
  alias Oli.Help

  def mount(_params, _session, socket) do
    changeset = Help.change_help_request(%HelpRequest{})

    {:ok,
     socket
     |> assign(:show_help_modal, false)
     |> assign(:submitted, false)
     |> assign(:sidebar_expanded, false)
     |> assign(:disable_sidebar?, false)
     |> assign(:changeset, changeset)}
    |> assign(
      :subjects,
      Enum.map(Oli.Help.HelpContent.list_subjects(), fn {key, desc} ->
        [value: key, key: desc]
      end)
    )
  end

  def handle_event("open_help_modal", _params, socket) do
    {:noreply, assign(socket, :show_help_modal, true)}
  end

  def handle_event("close_help_modal", _params, socket) do
    {:noreply, assign(socket, :show_help_modal, false)}
  end

  def handle_event("toggle_help_modal", _params, socket) do
    {:noreply, assign(socket, :show_help_modal, !socket.assigns.show_help_modal)}
  end

  def handle_event("validate", %{"help" => help_params}, socket) do
    changeset = Help.change_help_request(%HelpRequest{}, help_params)
    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("submit", %{"help" => help_params}, socket) do
    case Help.create_help_request(help_params) do
      {:ok, _req} ->
        {:noreply,
         socket
         |> assign(:submitted, true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def render(assigns) do
    ~H"""
    <script src="https://www.google.com/recaptcha/api.js">
    </script>

    <button id="hidden-support-button" class="hidden" phx-click="toggle_help_modal" />
    <div
      class="modal help-modal fade fixed top-0 left-0 w-full h-full outline-none overflow-x-hidden overflow-y-auto z-50"
      id="help-modal"
      tabindex="-1"
      aria-labelledby="exampleModalLabel"
      aria-hidden="false"
    >
      <div class="modal-dialog modal-lg relative w-auto pointer-events-none">
        <div
          id="inside_modal"
          class="modal-content border-none shadow-lg relative flex flex-col w-full pointer-events-auto bg-white bg-clip-padding rounded-md outline-none"
        >
          <.form
            :let={f}
            for={@changeset}
            id="form-request-help"
            phx-change="validate"
            phx-submit="submit"
          >
            <div class="modal-header flex flex-shrink-0 items-center justify-between p-4 border-b border-gray-200 rounded-t-md">
              <h5 class="modal-title text-xl font-medium leading-normal inline-flex">
                <span>Tech Support</span>
              </h5>
              <button
                type="button"
                class="btn-close box-content w-4 h-4 p-1 border-none rounded-none opacity-50 focus:shadow-none focus:outline-none focus:opacity-100 hover:opacity-75 hover:no-underline"
                phx-click="close_modal"
                aria-label="Close"
              >
                <i class="fa-solid fa-xmark fa-xl"></i>
              </button>
            </div>
            <div class="modal-body relative p-4">
              <h5 :if={@submitted} id="help-success-message" class="text-success">
                Your help request has been submitted
              </h5>
              <div :if={!@submitted} id="help-form">
                <.input id="location" type="hidden" field={@changeset[:location]} />
                <.input id="cookies_enabled" type="hidden" field={@changeset[:cookies_enabled]} />
                <div class="mb-6">
                  <% knowledge_base_link = Application.fetch_env!(:oli, :help)[:knowledge_base_link] %>
                  <.link href={knowledge_base_link}>
                    Find answers quickly in the Torus knowledge base
                  </.link>
                </div>
                <div class="form-group mb-3">
                  <.label for="subject" class="control-label">Subject:</.label>

                  <.input
                    id="subject"
                    type="select"
                    options={
                      Enum.map(Oli.Help.HelpContent.list_subjects(), fn {key, desc} ->
                        [value: key, key: desc]
                      end)
                    }
                    field={@changeset[:subject]}
                    class={"form-control" <> error_class(@changeset, :message, "is-invalid")}
                    required={true}
                    label="Select from the list of topics provided."
                  />
                </div>
                <div class="form-group mb-3">
                  <.label for="message" class="control-label">Questions or Comments:</.label>

                  <.input
                    id="message"
                    type="textarea"
                    field={@changeset[:message]}
                    class={"form-control" <> error_class(@changeset, :message, "is-invalid")}
                    required={true}
                    rows="8"
                  />

                  <%= error_tag(@changeset, :message) %>
                </div>
                <div class="input-group mb-3">
                  <div id="help-captcha"></div>
                  <%= error_tag(@changeset, :captcha) %>
                </div>
                <div
                  id="help-error-message"
                  class="hidden input-group mb-3 alert alert-danger"
                  role="alert"
                >
                </div>
              </div>
            </div>
            <div class="modal-footer flex flex-shrink-0 flex-wrap items-center justify-end p-4 border-t border-gray-200 rounded-b-md">
              <div :if={!@submitted} id="help-form-buttons">
                <button type="button" class="btn btn-link ml-2" phx-click="close_modal">
                  Cancel
                </button>
                <%= submit("Send Request",
                  id: "button-create-author",
                  class: "btn btn-primary ml-2",
                  phx_disable_with: "Requesting help..."
                ) %>
              </div>
              <button
                :if={@submitted}
                id="help-form-ok-button"
                type="button"
                class="btn btn-primary px-4"
                phx-click="close_modal"
              >
                Ok
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>

    <script>
      let helpRecapture = null;

      const showHelpModal = () => {
      $('#help-modal').modal('show');

      const formElement = document.getElementById('help-form');
      formElement.classList.remove('hidden');

      const formButtons = document.getElementById('help-form-buttons')
      formButtons.classList.remove('hidden');

      const successElement = document.getElementById('help-success-message');
      successElement.classList.add('hidden');

      const okButton = document.getElementById('help-form-ok-button');
      okButton.classList.add('hidden');

      document.getElementById('location').value = window.location.href
      if (typeof document.cookie == "undefined" || typeof navigator == "undefined" || !navigator.cookieEnabled) {
        document.getElementById('cookies_enabled').value = false;
      } else {
        document.getElementById('cookies_enabled').value = true;
      }
      if (helpRecapture != null) {
        grecaptcha.reset(helpRecapture);
        document.getElementById('help-captcha').value = "";
      } else {
        helpRecapture = grecaptcha.render('help-captcha', {
          'sitekey': '<%= Application.fetch_env!(:oli, :recaptcha)[:site_key] %>',  // required
          'theme': 'light' // optional
        });
      }
      }

      window.showHelpModal = showHelpModal;

      const helpForm = document.querySelector('#form-request-help')
      if (helpForm) {
      helpForm.addEventListener("submit", async function (event) {
        event.preventDefault();
        const form = event.target;

        const errorElement = document.getElementById('help-error-message');
        errorElement.classList.add('hidden');

        const result = await fetch('<%= Routes.help_path(OliWeb.Endpoint, :create) %>', {
          method: form.method,
          body: new URLSearchParams([...(new FormData(form))]),
        }).then((response) => response.json())
                .then((json) => {
                  const formElement = document.getElementById('help-form');
                  formElement.classList.add('hidden');

                  const formButtons = document.getElementById('help-form-buttons')
                  formButtons.classList.add('hidden');

                  const successElement = document.getElementById('help-success-message');
                  successElement.innerHTML = json.info;
                  successElement.classList.remove('hidden');

                  const okButton = document.getElementById('help-form-ok-button');
                  okButton.classList.remove('hidden');

                  document.getElementById("support-button")?.classList.remove('underline', 'underline-offset-8');
                  return json
                })
                .catch((error) => {
                  const errorElement = document.getElementById('help-error-message');
                  errorElement.innerHTML = "We are unable to forward your help request at the moment";
                  errorElement.classList.remove('hidden');
                  return error
                });
        });
      }

      window.addEventListener("maybe_add_underline_classes", e => {
      document.getElementById("support-button").classList.add('underline', 'underline-offset-8');
      });

      function maybe_remove_undeline_classes() {
      document.getElementById("support-button")?.classList.remove('underline', 'underline-offset-8');
      };

      document.addEventListener('click', (event) => {
      const target = document.querySelector('#inside_modal');
      const withinBoundaries = event.composedPath().includes(target);
      if (!withinBoundaries) {maybe_remove_undeline_classes();}
      });
    </script>
    """
  end
end
