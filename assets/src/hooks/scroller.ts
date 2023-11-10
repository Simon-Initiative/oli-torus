export const Scroller = {
  // This hook makes two listeners than can be executed from the server side.
  //
  // ** Scroll to Target **
  // Is used to scroll to a specific element on the page.
  // It is triggered from the backend as follows:
  //
  //    def handle_event(..., socket) do
  //      {:no_reply, push_event(socket, "scroll-to-target", %{id: "element-id", offset: 50})
  //    end
  // or
  //    def handle_event(..., socket) do
  //      {:no_reply, push_event(socket, "scroll-to-target", %{id: "element-id"})
  //    end
  //
  // Expects the id of the element to scroll to and an optional offset
  // to add to the scroll position. The optional offset is to consider the case, for example,
  // where you have a fixed header and you want to scroll to the element but you want to
  // consider the height of the header when scrolling to the element.
  //
  // ** Enable Slider Buttons **
  // It initializes the slider buttons the first time the liveview is mounted (actually, after the metrics are fetched).
  // It is triggered from the backend as follows:
  //
  //    def handle_info(..., socket) do
  //      {:no_reply, push_event(socket, "enable-slider-buttons", %{unit_uuids: ["uuid1", "uuid2"]})
  //    end
  //
  // Expects the uuids of the sliders to enable buttons on.
  // The enabled buttons will scroll on click 2/3 of the width of the slider.
  // It also hides or shows the buttons after window resize
  //
  // ** Hide or Show Buttons on Sliders **
  // It hides or shows the slider buttons depending on the slider scroll position.
  // It should be triggered from the backend when user interacts with page
  // and a handle_event is triggered as follows:
  //
  //    def handle_event(..., socket) do
  //      {:no_reply, push_event(socket, "hide-or-show-buttons-on-sliders", %{unit_uuids: ["uuid1", "uuid2"]})
  //    end

  mounted() {
    const hide_or_show_slider_buttons = (
      slider: HTMLElement | null,
      sliderRightButton: HTMLElement | null,
      sliderLeftButton: HTMLElement | null,
    ) => {
      // early return if slider is not found
      if (!slider) {
        return;
      }

      // show right button if slider is scrollable
      if (slider.scrollWidth > slider.clientWidth) {
        sliderRightButton?.classList.remove('hidden');
        sliderRightButton?.classList.add('flex');
      } else {
        sliderRightButton?.classList.remove('flex');
        sliderRightButton?.classList.add('hidden');
      }

      if (slider.scrollLeft === 0) {
        // If the left part is fully visible, hide the left button
        sliderLeftButton?.classList.add('hidden');
        sliderLeftButton?.classList.remove('flex');
      } else {
        // Otherwise, show it
        sliderLeftButton?.classList.remove('hidden');
        sliderLeftButton?.classList.add('flex');
      }
    };

    window.addEventListener('phx:scroll-to-target', (e: Event) => {
      const el = document.getElementById((e as CustomEvent).detail.id);
      const offset = (e as CustomEvent).detail.offset || 0;
      if (el) {
        window.scrollTo({ top: el.offsetTop - offset, behavior: 'smooth' });
      }
    });

    window.addEventListener('phx:enable-slider-buttons', (e: Event) => {
      const uuids = (e as CustomEvent).detail.unit_uuids;

      uuids.forEach((uuid: string) => {
        const slider = document.getElementById('slider_' + uuid);
        const sliderRightButton = document.getElementById('slider_right_button_' + uuid);
        const sliderLeftButton = document.getElementById('slider_left_button_' + uuid);

        hide_or_show_slider_buttons(slider, sliderRightButton, sliderLeftButton);

        // add click event listeners to the right and left buttons
        // to scroll 2/3 of the width of the slider
        sliderRightButton?.addEventListener('click', () => {
          slider?.scrollBy({ left: slider.clientWidth * (2 / 3), behavior: 'smooth' });
        });
        sliderLeftButton?.addEventListener('click', () => {
          slider?.scrollBy({ left: -slider.clientWidth * (2 / 3), behavior: 'smooth' });
        });
      });

      // we also need to enable/disable the right slider button on window resize
      window.addEventListener('resize', () => {
        uuids.forEach((uuid: string) => {
          const slider = document.getElementById('slider_' + uuid);
          const sliderRightButton = document.getElementById('slider_right_button_' + uuid);
          const sliderLeftButton = document.getElementById('slider_left_button_' + uuid);
          hide_or_show_slider_buttons(slider, sliderRightButton, sliderLeftButton);
        });
      });
    });

    window.addEventListener('phx:hide-or-show-buttons-on-sliders', (e: Event) => {
      const uuids = (e as CustomEvent).detail.unit_uuids;

      uuids.forEach((uuid: string) => {
        const slider = document.getElementById('slider_' + uuid);
        const sliderRightButton = document.getElementById('slider_right_button_' + uuid);
        const sliderLeftButton = document.getElementById('slider_left_button_' + uuid);

        hide_or_show_slider_buttons(slider, sliderRightButton, sliderLeftButton);
      });
    });
  },
};
