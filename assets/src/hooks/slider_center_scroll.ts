export const SliderCenterScroll = {
  // this hook still does not work exactly as expected (in partiular for small screens).
  // Some adjustments (probably to consider the margins) are still needed
  // to get the clicked card end up centerd in the slider after auto-scrolling.

  mounted() {
    // Define the cards within the slider
    const cards = this.el.querySelectorAll('.slider-card');

    // Add a click event to each card
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

        // Delay the scrolling to be visible by the user...
        setTimeout(() => {
          this.el.scrollTo({
            left: scrollLeft,
            behavior: 'smooth',
          });
        }, 100);
      });
    });
  },
};
