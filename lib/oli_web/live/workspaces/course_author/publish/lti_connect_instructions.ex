defmodule OliWeb.Workspaces.CourseAuthor.Publish.LtiConnectInstructions do
  use OliWeb, :html

  alias OliWeb.Workspaces.CourseAuthor.Publish.LmsUrlToCopy

  attr(:lti_connect_info, :map, required: true)
  attr(:id, :string, required: true)

  def render(assigns) do
    ~H"""
    <div
      class="modal fade fixed top-0 left-0 hidden w-full h-full outline-none overflow-x-hidden overflow-y-auto"
      id={@id}
      tabindex="-1"
      aria-labelledby="exampleModalLgLabel"
      aria-modal="true"
      role="dialog"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-lg relative w-auto pointer-events-none">
        <div class="modal-content border-none shadow-lg relative flex flex-col w-full pointer-events-auto bg-white bg-clip-padding rounded-md outline-none">
          <div class="modal-header flex flex-shrink-0 items-center justify-between p-4 border-b border-gray-200 rounded-t-md">
            <h5 class="text-xl font-medium leading-normal" id="exampleModalLgLabel">
              Connect to LMS
            </h5>
            <button
              type="button"
              class="btn-close box-content p-1 border-none rounded-none opacity-50 focus:shadow-none focus:outline-none focus:opacity-100 hover:opacity-75 hover:no-underline"
              data-bs-dismiss="modal"
              aria-label="Close"
            >
              <i class="fa-solid fa-xmark fa-xl"></i>
            </button>
          </div>

          <div class="modal-body relative p-4">
            <div class="text-center">
              <h4>Deliver this course through your institution's LMS</h4>
              <p>
                Connect your institution's LMS using LTI 1.3 to deliver course materials to students.
              </p>
              <br />

              <div id="lms-config-details">
                <hr class="my-3" />
                <p class="my-3 text-secondary">
                  Select your institution's LMS family below to show configuration instructions:
                </p>
                <ul class="nav nav-pills justify-content-center mb-3" id="pills-tab" role="tablist">
                  <li class="nav-item">
                    <a
                      class="nav-link active"
                      id="pills-canvas-tab"
                      data-bs-toggle="pill"
                      href="#pills-canvas"
                      role="tab"
                      aria-controls="pills-canvas"
                      aria-selected="true"
                    >
                      Canvas
                    </a>
                  </li>
                  <%= if @lti_connect_info.blackboard_application_client_id do %>
                    <li class="nav-item">
                      <a
                        class="nav-link"
                        id="pills-blackboard-tab"
                        data-bs-toggle="pill"
                        href="#pills-blackboard"
                        role="tab"
                        aria-controls="pills-blackboard"
                        aria-selected="false"
                      >
                        Blackboard
                      </a>
                    </li>
                  <% end %>
                  <li class="nav-item">
                    <a
                      class="nav-link"
                      id="pills-other-tab"
                      data-bs-toggle="pill"
                      href="#pills-other"
                      role="tab"
                      aria-controls="pills-other"
                      aria-selected="false"
                    >
                      Other LMS
                    </a>
                  </li>
                </ul>

                <div class="tab-content text-left p-3" id="pills-tabContent">
                  <div
                    class="tab-pane fade show active"
                    id="pills-canvas"
                    role="tabpanel"
                    aria-labelledby="pills-canvas-tab"
                  >
                    <p>
                      Please refer to the
                      <a
                        class="external"
                        href="https://community.canvaslms.com/t5/Admin-Guide/How-do-I-configure-an-LTI-key-for-an-account/ta-p/140"
                        target="_blank"
                      >
                        Canvas Documentation on LTI key configuration
                      </a>
                      to create
                      a new developer key. Using the <strong>Enter JSON URL</strong>
                      option, copy the url below and paste into the JSON URL field.
                    </p>

                    <div class="mt-2">
                      <strong>Developer Key JSON URL:</strong>
                      <div class="input-group input-group-sm mb-3">
                        <input
                          type="text"
                          id="canvas_developer_key_url"
                          class="form-control"
                          value={@lti_connect_info.canvas_developer_key_url}
                          phx-hook="LtiConnectInstructions"
                          readonly
                        />
                        <div class="input-group-append">
                          <button
                            id="btnDeveloperKey"
                            class="clipboardjs btn btn-xs btn-outline-primary"
                            data-clipboard-target="#canvas_developer_key_url"
                            phx-hook="CopyListener"
                          >
                            <i class="far fa-clipboard"></i> Copy
                          </button>
                        </div>
                      </div>
                      <strong class="mt-1">Options</strong>
                      <div>
                        <input
                          id="course_navigation_default"
                          type="checkbox"
                          phx-hook="LtiConnectInstructions"
                        />
                        <label for="course_navigation_default">
                          Disable course navigation placement by default
                        </label>
                      </div>
                    </div>
                  </div>

                  <%= if @lti_connect_info.blackboard_application_client_id do %>
                    <div
                      class="tab-pane fade"
                      id="pills-blackboard"
                      role="tabpanel"
                      aria-labelledby="pills-other-tab"
                    >
                      <p>
                        Please refer to the
                        <a
                          href="https://help.blackboard.com/Learn/Administrator/SaaS/Integrations/Learning_Tools_Interoperability"
                          target="_blank"
                        >
                          Blackboard Documentation on LTI 1.3 tool configuration
                        </a>
                        for full configuration instructions.
                        Use the <strong>Client ID</strong>
                        below to configure Torus as an LTI 1.3 tool.
                      </p>

                      <div>
                        <strong>Client ID:</strong>
                        <div class="input-group input-group-sm mb-3">
                          <input
                            type="text"
                            id="blackboard_application_client_id"
                            class="form-control"
                            value={@lti_connect_info.blackboard_application_client_id}
                            readonly
                          />
                          <div class="input-group-append">
                            <button
                              id="btnClientId"
                              class="clipboardjs btn btn-xs btn-outline-primary"
                              data-clipboard-target="#blackboard_application_client_id"
                              phx-hook="CopyListener"
                            >
                              <i class="far la-clipboard"></i> Copy
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>

                  <div
                    class="tab-pane fade"
                    id="pills-other"
                    role="tabpanel"
                    aria-labelledby="pills-other-tab"
                  >
                    <LmsUrlToCopy.render
                      title="Tool URL"
                      id="tool_url"
                      value={@lti_connect_info.tool_url}
                    />

                    <LmsUrlToCopy.render
                      title="Initiate login URL"
                      id="initiate_login_url"
                      value={@lti_connect_info.initiate_login_url}
                    />

                    <LmsUrlToCopy.render
                      title="Public Keyset URL"
                      id="public_keyset_url"
                      value={@lti_connect_info.public_keyset_url}
                    />

                    <LmsUrlToCopy.render
                      title="Redirection URI(s)"
                      id="redirect_uris"
                      value={@lti_connect_info.redirect_uris}
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
