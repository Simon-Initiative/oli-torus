export const SliderScroll = {
  // This hook is used to scroll the slider to the clicked card
  // and to hide or show the left and right button depending on the scroll position.

  mounted() {
    // Define the cards within the slider and the righ and left button
    const cards = this.el.querySelectorAll('.slider-card');
    const unit_uuid = this.el.dataset.uuid;
    const sliderLeftButton = document.getElementById('slider_left_button_' + unit_uuid);
    const sliderRightButton = document.getElementById('slider_right_button_' + unit_uuid);

    // Add a click event to each card that scrolls the slider to the clicked card
    // and animates it with a pulse effect
    cards.forEach((card: HTMLElement) => {
      card.addEventListener('click', () => {
        // Calculate the position to scroll to
        const sliderPaddingLeft = parseInt(getComputedStyle(this.el).paddingLeft);
        const sliderPaddingRight = parseInt(getComputedStyle(this.el).paddingRight);
        const cardMarginLeft = parseInt(getComputedStyle(card).marginLeft);
        const cardMarginRight = parseInt(getComputedStyle(card).marginRight);

        const adjustedSliderWidth = this.el.clientWidth - sliderPaddingLeft - sliderPaddingRight;
        const adjustedCardWidth = card.clientWidth + cardMarginLeft + cardMarginRight;

        const sliderCenter = adjustedSliderWidth / 2;
        const cardCenter = adjustedCardWidth / 2;

        const scrollLeft = card.offsetLeft - sliderCenter + cardCenter - sliderPaddingLeft;

        // Scroll to the position
        this.el.scrollTo({
          left: scrollLeft,
          behavior: 'smooth',
        });

        // pulse animation
        card.classList.add('animate-[pulse_0.5s_cubic-bezier(0.4,0,0.6,1)]');
      });
    });

    // hide or show the button depending on the scroll position
    this.el.addEventListener('scroll', () => {
      const slider = this.el;

      if (slider.scrollLeft === 0) {
        // If the left part is fully visible, hide the left button
        sliderLeftButton?.classList.add('hidden');
        sliderLeftButton?.classList.remove('flex');
      } else {
        // Otherwise, show it
        sliderLeftButton?.classList.remove('hidden');
        sliderLeftButton?.classList.add('flex');
      }

      if (slider.scrollWidth - slider.clientWidth === slider.scrollLeft) {
        sliderRightButton?.classList.add('hidden');
        sliderRightButton?.classList.remove('flex');
      } else {
        sliderRightButton?.classList.remove('hidden');
        sliderRightButton?.classList.add('flex');
      }
    });
  },
};
