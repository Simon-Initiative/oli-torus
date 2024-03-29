export const lockScroll = () => {
  // From https://github.com/excid3/tailwindcss-stimulus-components/blob/master/src/modal.js
  // Add right padding to the body so the page doesn't shift when we disable scrolling
  const scrollbarWidth = window.innerWidth - document.documentElement.clientWidth;
  document.body.style.paddingRight = `${scrollbarWidth}px`;
  // Save the scroll position
  const savedScrollPosition = window.pageYOffset || document.body.scrollTop;
  // Add classes to body to fix its position
  document.body.classList.add('fix-position');
  // Add negative top position in order for body to stay in place
  document.body.style.top = `-${savedScrollPosition}px`;

  return savedScrollPosition;
};

export const unlockScroll = (restoreScrollPosition?: number) => {
  // From https://github.com/excid3/tailwindcss-stimulus-components/blob/master/src/modal.js
  // Remove tweaks for scrollbar
  document.body.style.paddingRight = '';
  // Remove classes from body to unfix position
  document.body.classList.remove('fix-position');
  // Restore the scroll position of the body before it got locked
  if (restoreScrollPosition) document.documentElement.scrollTop = restoreScrollPosition;
  // Remove the negative top inline style from body
  document.body.style.top = '';
};
