const scrollPositions = new Map();

function updateCurrentScrollPosition(cardId: string, scrollPosition: number) {
  scrollPositions.set(cardId, scrollPosition);
}

function getCurrentScrollPosition(cardId: string) {
  return scrollPositions.get(cardId) || 0.0;
}

export const SliderScroll = {
  // This hook is used to scroll the slider to the clicked card to get it centered,
  // to hide or show the left and right button depending on the scroll position.
  // and to disable the x scroll when a card is expanded.
  // It also saves the scroll position of each slider to restore it when the slider is updated
  // (since we use temporary assigns in the liveview, the slider is updated evertime a module is selecting,
  // reseting the scroll position to 0, so we need to save it and restore it after the update)

  mounted() {
    // Define the cards within the slider and the righ and left button
    const cards = this.el.querySelectorAll('.slider-card');
    const unit_resource_id = this.el.dataset.resource_id;
    const sliderLeftButton = document.getElementById('slider_left_button_' + unit_resource_id);
    const sliderRightButton = document.getElementById('slider_right_button_' + unit_resource_id);

    // hide or show the slider buttons depending on the scroll position
    // and update the current position in the scrollPositions map
    this.el.addEventListener('scroll', () => {
      const slider = this.el;

      updateCurrentScrollPosition(this.el.dataset.resource_id, slider.scrollLeft);

      if (slider.scrollLeft <= 0) {
        // If the left part is fully visible, hide the left button
        sliderLeftButton?.classList.add('hidden');
        sliderLeftButton?.classList.remove('flex');
      } else {
        // Otherwise, show it
        sliderLeftButton?.classList.remove('hidden');
        sliderLeftButton?.classList.add('flex');
      }

      // we add 5 to the scrollLeft value to avoid the sliderRightButton to get visible even when scrolling is at the end
      if (slider.scrollLeft + 5 >= slider.scrollWidth - slider.clientWidth) {
        sliderRightButton?.classList.add('hidden');
        sliderRightButton?.classList.remove('flex');
      } else {
        sliderRightButton?.classList.remove('hidden');
        sliderRightButton?.classList.add('flex');
      }
    });

    this.el.setAttribute('style', 'overflow-x: scroll;');

    // if any of the cards has the aria-expanded attribute set to true,
    // disable x scroll in that slider after 700ms (to allow the scroll animation to end first)
    cards.forEach((card: HTMLElement) => {
      if (card.getAttribute('aria-expanded') === 'true') {
        setTimeout(() => {
          this.el.setAttribute('style', 'overflow-x: hidden;');
        }, 700);
      }
    });
  },
  updated() {
    this.el.setAttribute('style', 'overflow-x: scroll;');

    // re-apply the scroll position the slider had before the unit was updated by liveview.
    this.el.scrollTo({
      left: getCurrentScrollPosition(this.el.dataset.resource_id),
    });

    const cards = this.el.querySelectorAll('.slider-card');

    // disable x scroll in the slider after 700ms (to allow the scroll animation to end first)
    cards.forEach((card: HTMLElement) => {
      if (card.getAttribute('aria-expanded') === 'true') {
        setTimeout(() => {
          this.el.setAttribute('style', 'overflow-x: hidden;');
        }, 700);
      }
    });
  },
};
