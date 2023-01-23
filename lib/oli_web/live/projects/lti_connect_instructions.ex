defmodule OliWeb.Projects.LtiConnectInstructions do
  use Surface.Component

  alias OliWeb.Projects.LmsUrlToCopy

  prop lti_connect_info, :map, required: true

  def render(assigns) do
    ~F"""
      <div class="row justify-content-md-center mt-3">
        <div class="col-8">
          <div class="card">
            <div class="card-body text-center">
              <h5 class="card-title">Deliver this course through your institution's LMS</h5>
              <div class="card-text">
                <h6>Connect your institution's LMS using LTI 1.3 to deliver course materials to students.</h6>
                <small>Click the button below to get started.</small>
              </div>

              <a id="lms-config-details-toggle" href="#" class="btn btn-primary mt-3" data-toggle="collapse" data-target="#lms-config-details">Get Connected</a>

              <div id="lms-config-details" class="d-none">
                <hr class="my-3" />
                <h6 class="my-3 text-secondary">
                  Select your institution's LMS family below to show configuration instructions:
                </h6>
                <ul class="nav nav-pills justify-content-center mb-3" id="pills-tab" role="tablist">
                  <li class="nav-item">
                    <a class="nav-link active" id="pills-canvas-tab" data-toggle="pill" href="#pills-canvas" role="tab" aria-controls="pills-canvas" aria-selected="true">Canvas</a>
                  </li>
                  {#if @lti_connect_info.blackboard_application_client_id}
                    <li class="nav-item">
                      <a class="nav-link" id="pills-blackboard-tab" data-toggle="pill" href="#pills-blackboard" role="tab" aria-controls="pills-blackboard" aria-selected="false">Blackboard</a>
                    </li>
                  {/if}
                  <li class="nav-item">
                    <a class="nav-link" id="pills-other-tab" data-toggle="pill" href="#pills-other" role="tab" aria-controls="pills-other" aria-selected="false">Other LMS</a>
                  </li>
                </ul>

                <div class="tab-content text-left p-3" id="pills-tabContent">
                  <div class="tab-pane fade show active" id="pills-canvas" role="tabpanel" aria-labelledby="pills-canvas-tab">
                    <p>
                      Please refer to the <a href="https://community.canvaslms.com/t5/Admin-Guide/How-do-I-configure-an-LTI-key-for-an-account/ta-p/140" target="_blank">Canvas Documentation on LTI key configuration</a> to create
                      a new developer key. Using the <b>Enter JSON URL</b> option, copy the url below and paste into the JSON URL field.
                    </p>

                    <div class="mt-2">
                      <strong>Developer Key JSON URL:</strong>
                      <div class="input-group input-group-sm mb-3">
                        <input type="text" id="canvas_developer_key_url" class="form-control" value={@lti_connect_info.canvas_developer_key_url} readonly>
                        <div class="input-group-append">
                          <button class="clipboardjs btn btn-xs btn-outline-primary" data-clipboard-target="#canvas_developer_key_url">
                            <i class="lar la-clipboard"></i> Copy
                          </button>
                        </div>
                      </div>
                      <strong class="mt-1">Options</strong>
                      <div>
                        <input id="course_navigation_default" type="checkbox"> <label for="course_navigation_default">Disable course navigation placement by default</label>
                      </div>
                    </div>
                  </div>

                  {#if @lti_connect_info.blackboard_application_client_id}
                    <div class="tab-pane fade" id="pills-blackboard" role="tabpanel" aria-labelledby="pills-other-tab">
                      <p>
                        Please refer to the <a href="https://help.blackboard.com/Learn/Administrator/SaaS/Integrations/Learning_Tools_Interoperability" target="_blank">Blackboard Documentation on LTI 1.3 tool configuration</a> for full configuration instructions.
                        Use the <b>Client ID</b> below to configure Torus as an LTI 1.3 tool.
                      </p>

                      <div>
                        <strong>Client ID:</strong>
                        <div class="input-group input-group-sm mb-3">
                          <input type="text" id="blackboard_application_client_id" class="form-control" value={@lti_connect_info.blackboard_application_client_id} readonly>
                          <div class="input-group-append">
                            <button class="clipboardjs btn btn-xs btn-outline-primary" data-clipboard-target="#blackboard_application_client_id">
                              <i class="lar la-clipboard"></i> Copy
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  {/if}

                  <div class="tab-pane fade" id="pills-other" role="tabpanel" aria-labelledby="pills-other-tab">
                    <LmsUrlToCopy
                      title= "Tool URL"
                      id= "tool_url"
                      value= {@lti_connect_info.tool_url}
                    />

                    <LmsUrlToCopy
                      title= "Initiate login URL"
                      id= "initiate_login_url"
                      value= {@lti_connect_info.initiate_login_url}
                    />

                    <LmsUrlToCopy
                      title= "Public Keyset URL"
                      id= "public_keyset_url"
                      value= {@lti_connect_info.public_keyset_url}
                    />

                    <LmsUrlToCopy
                      title= "Redirection URI(s)"
                      id= "redirect_uris"
                      value= {@lti_connect_info.redirect_uris}
                    />
                  </div>
                </div>

              </div>
            </div>
          </div>
        </div>
      </div>

      <script src="//cdnjs.cloudflare.com/ajax/libs/clipboard.js/2.0.6/clipboard.min.js"></script>
      <script>
        var clipboard = new ClipboardJS('.clipboardjs.btn');

        clipboard.on('success', function(e) {
            const el = $(e.trigger);
            el.html('Copied!');
            setTimeout(() => el.html('<i class="lar la-clipboard"><\/i> Copy'), 5000);
        });

      </script>

      <script>
        $(function() {
          const canvas_developer_key_url = "{@canvas_developer_key_url}";
          const course_navigation_default_checkbox = document.querySelector('input#course_navigation_default');
          const canvas_developer_key_url_input = document.querySelector('input#canvas_developer_key_url');

          course_navigation_default_checkbox.addEventListener('change', function() {
            if (course_navigation_default_checkbox.checked) {
              canvas_developer_key_url_input.value = canvas_developer_key_url + '?course_navigation_default=disabled';
            } else {
              canvas_developer_key_url_input.value = canvas_developer_key_url;
            }
          });

          const lms_config_details = document.querySelector('#lms-config-details');
          const lms_config_details_toggle = document.querySelector('a#lms-config-details-toggle');

          lms_config_details_toggle.addEventListener('click', function() {
            lms_config_details.classList.toggle('d-none');
          })

        })
      </script>

    """
  end
end
