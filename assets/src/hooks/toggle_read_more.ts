// This hook shows the "Read more / Read less" button when the text content of the element
// the hook is attached to is larger than the container
// (in other words, when the ellipsis "..." is applied with CSS)
// It expects the id of the button that will be toggled depending on the text content size

// Example:
// In the liveview template:
//    <div phx-hook="ToggleReadMore" id="some_id" data-toggle_read_more_button_id="read_more_button"
//         style="display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical;"
//    >
//      <%= @text %>
//    </div>
//    <button id="read_more_button">Read more</button>

export const ToggleReadMore = {
  mounted() {
    this.initializeReadMoreToggle();
    // Bind handleResize to ensure 'this' refers to the hook object
    this.handleResize = this.handleResize.bind(this);
    window.addEventListener('resize', this.handleResize);
  },

  updated() {
    this.initializeReadMoreToggle();
  },

  destroyed() {
    window.removeEventListener('resize', this.handleResize);
  },

  handleResize() {
    // Now 'this' properly refers to the ToggleReadMore object
    this.initializeReadMoreToggle();
  },

  initializeReadMoreToggle() {
    const toggleReadMoreButton = document.getElementById(
      this.el.dataset.toggle_read_more_button_id,
    );

    if (!toggleReadMoreButton) {
      console.warn('ToggleReadMore: No button found.');
      return;
    }

    const isVisible = this.el.scrollHeight > this.el.clientHeight;
    toggleReadMoreButton.style.display = isVisible ? 'block' : 'none';
  },
};
