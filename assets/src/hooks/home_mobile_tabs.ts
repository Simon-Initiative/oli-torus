const activeClasses = ['border-Fill-Buttons-fill-primary', 'font-semibold'];

const inactiveClasses = ['border-transparent', 'font-normal'];

const getScrollBehavior = () =>
  window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth';

const getScrollOffset = (menu: HTMLElement) => {
  const header = document.getElementById('header');
  const headerHeight = header?.offsetHeight || 0;
  const menuHeight = menu?.classList.contains('is-visible') ? menu?.offsetHeight || 0 : 0;

  return headerHeight + menuHeight + 8;
};

export const HomeMobileTabs = {
  mounted() {
    this.activeTab = null;
    this.ticking = false;
    this.isDrawerOpen = false;

    this.assignElements = () => {
      this.tabsContainer = this.el.querySelector('[data-home-tabs-container]');
      this.tabs = Array.from(this.el.querySelectorAll('[data-home-tab]'));
      this.bannerTitle = document.getElementById('home-banner-title');
      this.banner = document.getElementById('home-continue-learning');
      this.sections = [];

      this.drawer = document.getElementById('home-drawer');
      this.drawerBackdrop = document.getElementById('home-drawer-backdrop');
      this.drawerToggle = this.el.querySelector('[data-drawer-toggle]');
      this.drawerCloseButtons = Array.from(document.querySelectorAll('[data-drawer-close]'));
      this.drawerItems = Array.from(document.querySelectorAll('[data-drawer-item]'));
    };

    this.removeEventListeners = () => {
      if (this.tabs) {
        this.tabs.forEach((tab: HTMLButtonElement) => {
          tab.removeEventListener('click', this.onTabClick);
        });
      }

      if (this.drawerToggle) {
        this.drawerToggle.removeEventListener('click', this.onDrawerToggle);
      }

      if (this.drawerCloseButtons) {
        this.drawerCloseButtons.forEach((button: Element) => {
          button.removeEventListener('click', this.closeDrawer);
        });
      }

      if (this.drawerItems) {
        this.drawerItems.forEach((item: HTMLButtonElement) => {
          item.removeEventListener('click', this.onDrawerItemClick);
        });
      }

      if (this.drawerBackdrop) {
        this.drawerBackdrop.removeEventListener('click', this.closeDrawer);
      }
    };

    this.addEventListeners = () => {
      this.tabs.forEach((tab: HTMLButtonElement) => {
        tab.addEventListener('click', this.onTabClick);
      });

      if (this.drawerToggle) {
        this.drawerToggle.addEventListener('click', this.onDrawerToggle);
      }

      this.drawerCloseButtons.forEach((button: Element) => {
        button.addEventListener('click', this.closeDrawer);
      });

      this.drawerItems.forEach((item: HTMLButtonElement) => {
        item.addEventListener('click', this.onDrawerItemClick);
      });

      if (this.drawerBackdrop) {
        this.drawerBackdrop.addEventListener('click', this.closeDrawer);
      }
    };

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
        item.setAttribute('aria-current', isActive ? 'true' : 'false');
        activeClasses.forEach((className) => item.classList.toggle(className, isActive));
        inactiveClasses.forEach((className) => item.classList.toggle(className, !isActive));
      });

      this.activeTab = tab;
      tab.scrollIntoView({ behavior: getScrollBehavior(), block: 'nearest', inline: 'start' });

      this.updateDrawerCheckmarks(tab.dataset.target);
    };

    this.updateDrawerCheckmarks = (targetId: string | undefined) => {
      if (!targetId) {
        return;
      }

      this.drawerItems.forEach((item: HTMLButtonElement) => {
        const checkmark = item.querySelector('[data-checkmark]');
        if (checkmark) {
          const isActive = item.dataset.target === targetId;
          checkmark.classList.toggle('hidden', !isActive);
        }
      });
    };

    this.openDrawer = () => {
      if (!this.drawer || !this.drawerBackdrop || this.isDrawerOpen) {
        return;
      }

      this.isDrawerOpen = true;
      this.drawer.classList.remove('hidden');
      this.drawerBackdrop.classList.remove('hidden');

      requestAnimationFrame(() => {
        this.drawer.classList.remove('translate-y-full');
        this.drawer.classList.add('translate-y-0');
      });

      document.body.style.overflow = 'hidden';

      if (this.activeTab?.dataset.target) {
        this.updateDrawerCheckmarks(this.activeTab.dataset.target);
      }
    };

    this.closeDrawer = () => {
      if (!this.drawer || !this.drawerBackdrop || !this.isDrawerOpen) {
        return;
      }

      this.isDrawerOpen = false;
      this.drawer.classList.remove('translate-y-0');
      this.drawer.classList.add('translate-y-full');

      setTimeout(() => {
        this.drawer.classList.add('hidden');
        this.drawerBackdrop.classList.add('hidden');
      }, 300);

      document.body.style.overflow = '';
    };

    this.onDrawerToggle = () => {
      if (this.isDrawerOpen) {
        this.closeDrawer();
      } else {
        this.openDrawer();
      }
    };

    this.onDrawerItemClick = (event: Event) => {
      const target = event.currentTarget as HTMLButtonElement;
      const sectionId = target?.dataset?.target;
      const section = sectionId ? document.getElementById(sectionId) : null;

      if (!section) {
        return;
      }

      this.closeDrawer();

      const tab = this.tabs.find(
        (t: HTMLButtonElement) => t.dataset.target === sectionId,
      ) as HTMLButtonElement;

      if (tab) {
        this.setActiveTab(tab);
      }

      const offset = getScrollOffset(this.el);
      const top = section.getBoundingClientRect().top + window.scrollY - offset;

      window.scrollTo({ top, behavior: getScrollBehavior() });
      if (!section.hasAttribute('tabindex')) {
        section.setAttribute('tabindex', '-1');
      }
      window.requestAnimationFrame(() => {
        section.focus({ preventScroll: true });
      });
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

      window.scrollTo({ top, behavior: getScrollBehavior() });
      if (!section.hasAttribute('tabindex')) {
        section.setAttribute('tabindex', '-1');
      }
      window.requestAnimationFrame(() => {
        section.focus({ preventScroll: true });
      });
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

    this.assignElements();
    this.addEventListeners();
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

  updated() {
    this.removeEventListeners();
    this.assignElements();
    this.addEventListeners();
    this.updateTabOrder();
    this.updateVisibility();
    this.onScroll();
  },

  destroyed() {
    this.removeEventListeners();
    window.removeEventListener('scroll', this.onScroll);
    if (this.onResize) {
      window.removeEventListener('resize', this.onResize);
    }

    document.body.style.overflow = '';
  },
};
