export const VideoPreview = {
  //  This hook is used to preview a video file when using phoenix live_upload/3.
  // It should be attached to a div that wraps a video input with

  // It expects the following attributes:
  // - ref: the reference of the entry to preview
  // - name: the name defined in allow_upload/3

  //          def mount(socket) do
  //           {:ok,
  //            |> allow_upload(:some_upload_name,
  //             accept: ~w(video/mp4),
  //             max_entries: 1,
  //             auto_upload: true,
  //           )}
  //          end
  //
  //          def render(assigns) do
  //           ~H"""
  //           ...
  //          <.live_file_input upload={:some_upload_name} />
  //          <article
  //            :for={entry <- @uploads[:some_upload_name].entries}
  //          >
  //           <div
  //             phx-hook="VideoPreview"
  //             ref={entry.ref}
  //             id={"video_preview_#{entry.ref}"}
  //             name={:some_upload_name}
  //           >
  //             <video>
  //               <source />
  //             </video>
  //           </div>
  //          </article>
  //           ...
  //           """
  //          end

  mounted() {
    const ref = this.el.getAttribute('ref');
    const allow_upload_name = this.el.getAttribute('name');

    const input = document.querySelector(`input[type="file"][name="${allow_upload_name}"]`);
    const files = (input as any).phxPrivate.files;
    const file = files.find((entry: any) => entry._phxRef == ref);

    if (file) {
      const source = this.el.querySelector('source');
      source.setAttribute('src', URL.createObjectURL(file));
    }
  },
};

// the following hook is used to pause all other videos when a video is selected (and played)
export const PauseOthersOnSelected = {
  mounted() {
    this.el.addEventListener('click', (e: any) => {
      const videos = document.querySelectorAll('video');

      const currentVideo = this.el;
      const otherVideos = Array.from(videos).filter((video) => video !== currentVideo);

      for (let i = 0; i < otherVideos.length; i++) {
        otherVideos[i].pause();
      }
    });
  },
};
