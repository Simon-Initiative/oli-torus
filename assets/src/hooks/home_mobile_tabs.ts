const activeClasses = ['border-delivery-primary', 'dark:border-delivery-primary-dark'];

const inactiveClasses = ['border-transparent'];

const getScrollOffset = (menu: HTMLElement) => {
  const header = document.getElementById('header');
  const headerHeight = header?.offsetHeight || 0;
  const menuHeight = menu?.classList.contains('is-visible') ? menu?.offsetHeight || 0 : 0;

  return headerHeight + menuHeight + 8;
};

export const HomeMobileTabs = {
  mounted() {
    this.tabsContainer = this.el.querySelector('[data-home-tabs-container]');
    this.tabs = Array.from(this.el.querySelectorAll('[data-home-tab]'));
    this.bannerTitle = document.getElementById('home-banner-title');
    this.banner = document.getElementById('home-continue-learning');
    this.sections = [];

    this.activeTab = null;
    this.ticking = false;

    this.updateTabOrder = () => {
      if (!this.tabsContainer) {
        return;
      }

      const pairs = this.tabs
        .map((tab: HTMLButtonElement) => {
          const targetId = tab.dataset.target;
          const section = targetId ? document.getElementById(targetId) : null;
          return section ? { tab, section } : null;
        })
        .filter(Boolean) as Array<{ tab: HTMLButtonElement; section: HTMLElement }>;

      pairs.sort((a, b) => a.section.offsetTop - b.section.offsetTop);
      pairs.forEach((pair) => this.tabsContainer.appendChild(pair.tab));
      this.tabs = pairs.map((pair) => pair.tab);
      this.sections = pairs.map((pair) => pair.section);
    };

    this.setActiveTab = (tab: HTMLButtonElement | null) => {
      if (!tab || this.activeTab === tab) {
        return;
      }

      this.tabs.forEach((item: HTMLButtonElement) => {
        const isActive = item === tab;
        item.setAttribute('aria-selected', isActive ? 'true' : 'false');
        activeClasses.forEach((className) => item.classList.toggle(className, isActive));
        inactiveClasses.forEach((className) => item.classList.toggle(className, !isActive));
      });

      this.activeTab = tab;
      tab.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'start' });
    };

    this.onTabClick = (event: Event) => {
      const target = event.currentTarget as HTMLButtonElement;
      const sectionId = target?.dataset?.target;
      const section = sectionId ? document.getElementById(sectionId) : null;

      if (!section) {
        return;
      }

      this.setActiveTab(target);
      const offset = getScrollOffset(this.el);
      const top = section.getBoundingClientRect().top + window.scrollY - offset;

      window.scrollTo({ top, behavior: 'smooth' });
    };

    this.updateVisibility = () => {
      if (!this.bannerTitle && !this.banner) {
        this.toggleMenuVisibility(true);
        return;
      }

      const header = document.getElementById('header');
      const headerHeight = header?.offsetHeight || 0;
      const sentinel = this.bannerTitle || this.banner;
      const sentinelBottom = sentinel.getBoundingClientRect().bottom;
      const shouldShow = sentinelBottom <= headerHeight;

      this.toggleMenuVisibility(shouldShow);
    };

    this.onScroll = () => {
      if (this.ticking) {
        return;
      }

      this.ticking = true;
      window.requestAnimationFrame(() => {
        this.ticking = false;
        this.updateVisibility();
        if (!this.sections.length) {
          return;
        }

        if (!this.el.classList.contains('is-visible')) {
          return;
        }

        const offset = getScrollOffset(this.el);
        let activeSection = this.sections[0];

        for (const section of this.sections) {
          const top = section.getBoundingClientRect().top - offset;
          if (top <= 0) {
            activeSection = section;
          } else {
            break;
          }
        }

        const activeTab = this.tabs.find(
          (tab: HTMLButtonElement) => tab.dataset.target === activeSection.id,
        );

        if (activeTab) {
          this.setActiveTab(activeTab);
        }
      });
    };

    this.toggleMenuVisibility = (visible: boolean) => {
      this.el.classList.toggle('hidden', !visible);
      this.el.classList.toggle('is-visible', visible);
    };

    this.tabs.forEach((tab: HTMLButtonElement) => {
      tab.addEventListener('click', this.onTabClick);
    });

    window.addEventListener('scroll', this.onScroll, { passive: true });
    this.onResize = () => {
      this.updateTabOrder();
      this.onScroll();
    };
    window.addEventListener('resize', this.onResize);

    this.updateTabOrder();
    this.updateVisibility();
    this.onScroll();
  },

  destroyed() {
    if (this.tabs) {
      this.tabs.forEach((tab: HTMLButtonElement) => {
        tab.removeEventListener('click', this.onTabClick);
      });
    }

    window.removeEventListener('scroll', this.onScroll);
    if (this.onResize) {
      window.removeEventListener('resize', this.onResize);
    }
  },
};
