export const FixedNavigationBar = {
  mounted() {
    const bottomBar = document.getElementById('bottom-bar');
    if (!bottomBar) return;

    let lastScrollTop = document.documentElement.scrollTop || window.scrollY;
    let isScrollingDown = false;

    const isMobile = () => window.innerWidth < 640; // sm breakpoint is 640px

    const updateDialoguePosition = (isBarVisible: boolean) => {
      // Fetch dialogue window fresh each time
      const dialogueWindow = document.querySelector('[data-dialogue-window]');
      if (!dialogueWindow) return;

      const dialogueElement = dialogueWindow as HTMLElement;

      if (isMobile()) {
        if (isBarVisible) {
          // When bar is visible, position dialogue at bottom-20 (current position)
          dialogueElement.style.setProperty('bottom', '5rem', 'important');
          dialogueElement.style.setProperty('margin-bottom', '0', 'important');
          dialogueElement.style.setProperty('padding-bottom', '0', 'important');
          dialogueElement.style.setProperty('transition', 'all 0.5s ease-in-out', 'important');
        } else {
          // When bar is hidden, position dialogue at bottom-0 (very bottom)
          dialogueElement.style.setProperty('bottom', '0px', 'important');
          dialogueElement.style.setProperty('margin-bottom', '0', 'important');
          dialogueElement.style.setProperty('padding-bottom', '0', 'important');
          dialogueElement.style.setProperty('transition', 'all 0.5s ease-in-out', 'important');
        }
      } else {
        // On desktop, remove inline styles and restore original classes
        dialogueElement.style.removeProperty('bottom');
        dialogueElement.style.removeProperty('margin-bottom');
        dialogueElement.style.removeProperty('padding-bottom');
        dialogueElement.style.removeProperty('transition');
      }
    };

    const updateBarVisibility = () => {
      const { scrollTop, scrollHeight } = document.documentElement;
      const windowHeight = window.innerHeight;
      const atBottom = scrollTop + windowHeight >= scrollHeight - 5;
      const noScroll = scrollHeight <= windowHeight;
      const shortScroll = scrollHeight - windowHeight <= 100;
      const isMobileDevice = isMobile();

      if (isMobileDevice && (atBottom || noScroll || shortScroll)) {
        bottomBar.classList.add('translate-y-0', 'opacity-100');
        bottomBar.classList.remove('translate-y-full', 'opacity-0');
        updateDialoguePosition(true);
        return;
      }

      if (isMobileDevice) {
        // Mobile behavior: show on scroll down, hide immediately on scroll up
        isScrollingDown = scrollTop > lastScrollTop;
        lastScrollTop = scrollTop;

        if (isScrollingDown && scrollTop > 100) {
          // Scrolling down and past 100px - show the bar
          bottomBar.classList.add('translate-y-0', 'opacity-100');
          bottomBar.classList.remove('translate-y-full', 'opacity-0');
          updateDialoguePosition(true);
        } else if (!isScrollingDown && scrollTop > 100) {
          // Scrolling up - hide the bar immediately
          bottomBar.classList.remove('translate-y-0', 'opacity-100');
          bottomBar.classList.add('translate-y-full', 'opacity-0');
          updateDialoguePosition(false);
        } else if (scrollTop <= 100) {
          // Near the top - hide the bar and position dialogue at bottom
          bottomBar.classList.remove('translate-y-0', 'opacity-100');
          bottomBar.classList.add('translate-y-full', 'opacity-0');
          updateDialoguePosition(false);
        }
      } else {
        // Desktop behavior: show at bottom or when no scroll
        if (atBottom || noScroll) {
          bottomBar.classList.add('translate-y-0', 'opacity-100');
          bottomBar.classList.remove('translate-y-full', 'opacity-0');
          updateDialoguePosition(true);
        } else {
          bottomBar.classList.remove('translate-y-0', 'opacity-100');
          bottomBar.classList.add('translate-y-full', 'opacity-0');
          updateDialoguePosition(false);
        }
      }
    };

    const handleScroll = () => {
      requestAnimationFrame(updateBarVisibility);
    };

    const resizeHandler = () => {
      updateBarVisibility();
      // Also update dialogue position on resize
      if (isMobile()) {
        // Derive visibility from actual bar state, not scroll position
        const isBarVisible = bottomBar.classList.contains('translate-y-0');
        updateDialoguePosition(isBarVisible);
      } else {
        updateDialoguePosition(false); // Reset to CSS classes on desktop
      }
    };

    // Set initial state
    if (isMobile()) {
      bottomBar.classList.remove('translate-y-0', 'opacity-100');
      bottomBar.classList.add('translate-y-full', 'opacity-0');
      updateDialoguePosition(false);
      requestAnimationFrame(updateBarVisibility);
    } else {
      requestAnimationFrame(updateBarVisibility);
    }

    window.addEventListener('scroll', handleScroll, { passive: true });
    window.addEventListener('resize', resizeHandler);

    this.cleanup = () => {
      window.removeEventListener('scroll', handleScroll);
      window.removeEventListener('resize', resizeHandler);
    };
  },

  destroyed() {
    this.cleanup?.();
  },
};
