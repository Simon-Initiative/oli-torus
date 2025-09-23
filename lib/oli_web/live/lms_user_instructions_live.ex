defmodule OliWeb.LmsUserInstructionsLive do
  use OliWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container-fluid">
      <div class="row">
        <div class="col-12">
          <div class="card">
            <div class="card-header">
              <h1 class="h3 mb-0">Account Type Mismatch</h1>
            </div>
            <div class="card-body">
              <div class="alert alert-info" role="alert">
                <h4 class="alert-heading">Different Account Types Required</h4>
                <p>
                  You are currently logged in with an LMS-connected account, but this course requires a Direct Delivery account.
                </p>
              </div>

              <div class="mb-4">
                <h5>Why is this happening?</h5>
                <p>
                  Torus has two different types of accounts:
                </p>
                <ul>
                  <li><strong>LMS-connected accounts:</strong> Used for courses accessed through your school's Learning Management System (Canvas, Blackboard, etc.)</li>
                  <li><strong>Direct Delivery accounts:</strong> Used for courses that don't require LMS integration</li>
                </ul>
                <p>
                  The course you're trying to access requires a Direct Delivery account, but you're currently logged in with an LMS-connected account.
                </p>
              </div>

              <div class="mb-4">
                <h5>How to access this course:</h5>
                <ol>
                  <li>
                    <strong>Log out of your current account</strong> using the menu at the top right of the page
                  </li>
                  <li>
                    <strong>Return to this enrollment URL</strong> and create a new Torus account using either:
                    <ul>
                      <li>Email and password</li>
                      <li>Sign In With Google</li>
                    </ul>
                  </li>
                  <li>
                    <strong>Complete the enrollment process</strong> with your new Direct Delivery account
                  </li>
                </ol>
              </div>

              <div class="mb-4">
                <h5>Important notes:</h5>
                <ul>
                  <li>Your LMS-connected account will continue to work for courses accessed through your school's LMS</li>
                  <li>Your Direct Delivery account will be used for courses that don't require LMS integration</li>
                  <li>Both accounts can use the same email address</li>
                  <li>Your work and progress will be separate between the two account types</li>
                </ul>
              </div>

              <div class="mb-4">
                <h5>Need help?</h5>
                <p>
                  If you have questions about which type of account to use for a specific course,
                  please contact your instructor. They can clarify whether the course should be
                  accessed through your school's LMS or through a Direct Delivery account.
                </p>
              </div>

              <div class="d-flex gap-2">
                <a href="/users/log_out" class="btn btn-primary">
                  <i class="fas fa-sign-out-alt me-1"></i>
                  Log Out and Create New Account
                </a>
                <a href="/" class="btn btn-secondary">
                  <i class="fas fa-home me-1"></i>
                  Go to Home
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
