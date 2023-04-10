defmodule OliWeb.Admin.Ingest.FAQ do
  use Surface.Component

  def render(assigns) do
    ~F"""
    <h3 class="display-5">FAQ</h3>

    <div class="accordion" id="accordionExample">
      <div class="card">
        <div class="card-header" id="headingOne">
          <h6 class="mb-0">
            <button class="btn btn-link btn-block text-left" type="button" data-bs-toggle="collapse" data-bs-target="#collapseOne" aria-expanded="true" aria-controls="collapseOne">
              How long does the ingestion process take?
            </button>
          </h6>
        </div>

        <div id="collapseOne" class="collapse show" aria-labelledby="headingOne" data-bs-parent="#accordionExample">
          <div class="card-body">
              It depends on the size of the course described in the digest, but expect the ingestion to take anywhere from a
              few seconds to a minute or two. After the ingestion finishes you will be taken to the Project Overview of the new project.
          </div>
        </div>
      </div>
      <div class="card">
        <div class="card-header" id="headingTwo">
          <h6 class="mb-0">
            <button class="btn btn-link btn-block text-left collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseTwo" aria-expanded="false" aria-controls="collapseTwo">
              Where does one get a course digest archive?
            </button>
          </h6>
        </div>
        <div id="collapseTwo" class="collapse" aria-labelledby="headingTwo" data-bs-parent="#accordionExample">
          <div class="card-body">
            An archive can be created manually or created from an OLI Legacy course using the <code>course-digest</code> creation tool at
    <a href="https://github.com/Simon-Initiative/course-digest">https://github.com/Simon-Initiative/course-digest</a>
          </div>
        </div>
      </div>
      <div class="card">
        <div class="card-header" id="headingThree">
          <h6 class="mb-0">
            <button class="btn btn-link btn-block text-left collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseThree" aria-expanded="false" aria-controls="collapseThree">
              How do I add authors to the course?
            </button>
          </h6>
        </div>
        <div id="collapseThree" class="collapse" aria-labelledby="headingThree" data-bs-parent="#accordionExample">
          <div class="card-body">
            After the course is created, from the <code>Overveiw</code> page, add additional authors.
          </div>
        </div>
      </div>
      <div class="card">
        <div class="card-header" id="four">
          <h6 class="mb-0">
            <button class="btn btn-link btn-block text-left collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseFour" aria-expanded="false" aria-controls="collapseFour">
              How can I learn more about the course ingest process and course digest format?
            </button>
          </h6>
        </div>
        <div id="collapseFour" class="collapse" aria-labelledby="four" data-bs-parent="#accordionExample">
          <div class="card-body">
             The Torus GitHub WIKI has documentation regarding ingestion.
          </div>
        </div>
      </div>
    </div>
    """
  end
end
