export const Scroller = {
  // This hook has four listeners than can be executed from the server side.
  //
  // ** Scroll Y to Target **
  // Is used to scroll to a specific element on the page in the Y direction.
  // It is triggered from the backend as follows:
  //
  //    def handle_event(..., socket) do
  //      {:no_reply, push_event(socket, "scroll-y-to-target", %{id: "element-id", offset: 50, scroll: true, scroll_delay: 500})}
  //    end
  //
  // Expects the id of the element to scroll to, an optional offset
  // to add to the scroll position, an optional pulse animtation boolean with its pulse_delay in milliseconds.
  // The optional offset is to consider the case, for example,
  // where you have a fixed header and you want to scroll to the element but you want to
  // consider the height of the header when scrolling to the element.
  //
  //  ** Scroll X to Target **
  // Is used to scroll to a specific element on the unit slider in the X direction.
  // It is triggered from the backend as follows:
  //
  //    def handle_event(..., socket) do
  //      {:no_reply, push_event(socket, "scroll-x-to-card-in-slider",
  //                              %{
  //                                card_id: "module_#{module_resource_id}",
  //                                scroll_delay: 300,
  //                                unit_resource_id: unit_resource_id,
  //                                pulse_target_id: "index_item_#{resource_id}",
  //                                pulse_delay: 330
  //                              }
  //                             )
  //       }
  //    end
  //
  // Expects the card_id of the element to scroll X to, the unit_resource_id of the slider that contains that module,
  // the scroll animation delay in milliseconds (defaults to 0), the id of the element to animate with a pulse effect (optional),
  // and the pulse animation delay in milliseconds (defaults to 300).
  //
  // ** Enable Slider Buttons **
  // It initializes the slider buttons the first time the liveview is mounted (actually, after the metrics are fetched).
  // It is triggered from the backend as follows:
  //
  //    def handle_info(..., socket) do
  //      {:no_reply, push_event(socket, "enable-slider-buttons", %{unit_resource_ids: ["resource_id1", "resource_id2"]})
  //    end
  //
  // Expects the resource_ids of the sliders to enable buttons on.
  // The enabled buttons will scroll on click 2/3 of the width of the slider.
  // It also hides or shows the buttons after window resize
  //
  // ** Hide or Show Buttons on Sliders **
  // It hides or shows the slider buttons depending on the slider scroll position.
  // It should be triggered from the backend when user interacts with page
  // and a handle_event is triggered as follows:
  //
  //    def handle_event(..., socket) do
  //      {:no_reply, push_event(socket, "hide-or-show-buttons-on-sliders", %{unit_resource_ids: ["resource_id1", "resource_id2"]})
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

      const updateSliderButtons = () => {
        // Show right button if slider is scrollable
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

      // Use requestAnimationFrame to ensure DOM updates (like scrollWidth)
      // are fully processed before determining slider buttons visibility.
      // This avoids layout inconsistencies when toggling slider content.
      requestAnimationFrame(updateSliderButtons);
    };

    window.addEventListener('phx:scroll-y-to-target', (e: Event) => {
      const detail = (e as CustomEvent).detail;
      const getElement = () =>
        document.getElementById(detail.id) || document.querySelector(`[role=${detail.role}]`);

      let el = getElement() as HTMLDivElement;
      if (!el) return;

      const scrollBehavior = detail.scroll_behavior || 'smooth';
      const offset = detail.offset || 0;

      setTimeout(() => {
        el = getElement() as HTMLDivElement;
        if (el) {
          window.scrollTo({ top: el.offsetTop - offset, behavior: scrollBehavior });
        }
      }, 400);

      if (detail.pulse) {
        setTimeout(() => {
          el = getElement() as HTMLDivElement;
          if (el) {
            el.classList.add('animate-[pulse_0.7s_cubic-bezier(0.4,0,0.6,1)2]');
          }
        }, detail.pulse_delay || 300);
      }
    });

    window.addEventListener('phx:pulse-target', (e: Event) => {
      const target = document.getElementById((e as CustomEvent).detail.target_id);

      if (target) {
        target.classList.add('animate-[pulse_0.7s_cubic-bezier(0.4,0,0.6,1)1]');
      }
    });

    window.addEventListener('phx:scroll-x-to-card-in-slider', (e: Event) => {
      setTimeout(() => {
        const target_card = document.getElementById((e as CustomEvent).detail.card_id);
        const pulse_target = document.getElementById((e as CustomEvent).detail.pulse_target_id);
        const unit_slider = document.getElementById(
          'slider_' + (e as CustomEvent).detail.unit_resource_id,
        );

        // early return if slider or card is not found
        if (!target_card || !unit_slider) {
          return;
        }

        const sliderPaddingLeft = parseInt(getComputedStyle(unit_slider).paddingLeft);
        const sliderPaddingRight = parseInt(getComputedStyle(unit_slider).paddingRight);
        const sliderMarginLeft = parseInt(getComputedStyle(unit_slider).marginLeft);
        const sliderMarginRight = parseInt(getComputedStyle(unit_slider).marginRight);
        const cardPaddingLeft = parseInt(getComputedStyle(target_card).paddingLeft);
        const cardPaddingRight = parseInt(getComputedStyle(target_card).paddingRight);
        const cardMarginLeft = parseInt(getComputedStyle(target_card).marginLeft);
        const cardMarginRight = parseInt(getComputedStyle(target_card).marginRight);

        const adjustedSliderWidth =
          unit_slider.clientWidth -
          sliderPaddingLeft -
          sliderPaddingRight -
          sliderMarginLeft -
          sliderMarginRight;
        const adjustedCardWidth =
          target_card.clientWidth +
          cardMarginLeft +
          cardMarginRight +
          cardPaddingLeft +
          cardPaddingRight;

        const sliderCenter = adjustedSliderWidth / 2;
        const cardCenter = adjustedCardWidth / 2;

        const scrollLeft = target_card.offsetLeft - sliderCenter + cardCenter - 3;

        // Scroll to the position
        unit_slider.scrollTo({
          left: scrollLeft,
          behavior: 'smooth',
        });

        // pulse animation after scroll
        if (pulse_target) {
          setTimeout(() => {
            pulse_target.classList.add('animate-[pulse_0.7s_cubic-bezier(0.4,0,0.6,1)2]');
          }, (e as CustomEvent).detail.pulse_delay || 300);
        }
      }, (e as CustomEvent).detail.scroll_delay || 0);
    });

    window.addEventListener('phx:enable-slider-buttons', (e: Event) => {
      const resource_ids = (e as CustomEvent).detail.unit_resource_ids;

      resource_ids.forEach((resource_id: string) => {
        const slider = document.getElementById('slider_' + resource_id);
        const sliderRightButton = document.getElementById('slider_right_button_' + resource_id);
        const sliderLeftButton = document.getElementById('slider_left_button_' + resource_id);

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
        resource_ids.forEach((resource_id: string) => {
          const slider = document.getElementById('slider_' + resource_id);
          const sliderRightButton = document.getElementById('slider_right_button_' + resource_id);
          const sliderLeftButton = document.getElementById('slider_left_button_' + resource_id);
          hide_or_show_slider_buttons(slider, sliderRightButton, sliderLeftButton);
        });
      });
    });

    window.addEventListener('phx:hide-or-show-buttons-on-sliders', (e: Event) => {
      const resource_ids = (e as CustomEvent).detail.unit_resource_ids;

      resource_ids.forEach((resource_id: string) => {
        const slider = document.getElementById('slider_' + resource_id);
        const sliderRightButton = document.getElementById('slider_right_button_' + resource_id);
        const sliderLeftButton = document.getElementById('slider_left_button_' + resource_id);

        hide_or_show_slider_buttons(slider, sliderRightButton, sliderLeftButton);
      });
    });
  },
};
