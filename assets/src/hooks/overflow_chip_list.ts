import type { Hook } from 'phoenix_live_view/assets/js/types/view_hook';

type OverflowChipListState = {
  __overflowChipListExpanded?: boolean;
  __overflowChipListClickHandler?: ((event: Event) => void) | null;
  __overflowChipListResizeHandler?: (() => void) | null;
  __overflowChipListResizeRaf?: number | null;
};

function chipElements(root: HTMLElement): HTMLElement[] {
  return Array.from(root.querySelectorAll<HTMLElement>('[data-overflow-chip]'));
}

function toggleElement(root: HTMLElement): HTMLButtonElement | null {
  return root.querySelector<HTMLButtonElement>('[data-overflow-toggle]');
}

function gapSize(root: HTMLElement): number {
  const styles = window.getComputedStyle(root);
  const gap = styles.columnGap || styles.gap || '0';
  const parsed = Number.parseFloat(gap);
  return Number.isFinite(parsed) ? parsed : 0;
}

function setExpanded(root: HTMLElement, expanded: boolean) {
  root.classList.toggle('flex-wrap', expanded);
  root.classList.toggle('whitespace-normal', expanded);
  root.classList.toggle('overflow-visible', expanded);
  root.classList.toggle('items-start', expanded);

  root.classList.toggle('whitespace-nowrap', !expanded);
  root.classList.toggle('overflow-hidden', !expanded);
  root.classList.toggle('items-center', !expanded);
}

function toggleLabel(hiddenCount: number): string {
  return hiddenCount > 0 ? `+${hiddenCount} more` : 'Show less';
}

function updateToggle(root: HTMLElement, expanded: boolean, hiddenCount: number, visible: boolean) {
  const toggle = toggleElement(root);

  if (!toggle) {
    return;
  }

  toggle.setAttribute('aria-expanded', expanded ? 'true' : 'false');
  toggle.setAttribute('aria-hidden', visible ? 'false' : 'true');

  if (visible) {
    toggle.classList.remove('hidden');
    toggle.classList.add('inline-flex');
  } else {
    toggle.classList.add('hidden');
    toggle.classList.remove('inline-flex');
  }

  toggle.textContent = expanded ? 'Show less' : toggleLabel(hiddenCount);
  toggle.setAttribute('aria-label', expanded ? 'Show fewer recipients' : 'Show all recipients');
}

function showAllChips(root: HTMLElement) {
  chipElements(root).forEach((chip) => {
    chip.style.display = '';
  });
  updateToggle(root, true, 0, true);
}

function scheduleLayout(root: HTMLElement, expanded: boolean) {
  const state = root as HTMLElement & OverflowChipListState;

  if (state.__overflowChipListResizeRaf != null) {
    cancelAnimationFrame(state.__overflowChipListResizeRaf);
  }

  state.__overflowChipListResizeRaf = requestAnimationFrame(() => {
    state.__overflowChipListResizeRaf = null;
    layout(root, expanded);
  });
}

function collapseToFit(root: HTMLElement) {
  const chips = chipElements(root);
  const toggle = toggleElement(root);

  if (!toggle) {
    return;
  }

  chips.forEach((chip) => {
    chip.style.display = '';
  });

  updateToggle(root, false, 0, false);

  const availableWidth = root.clientWidth;
  const gap = gapSize(root);

  if (availableWidth <= 0 || chips.length === 0) {
    return;
  }

  const chipWidths = chips.map((chip) => chip.getBoundingClientRect().width);

  const measureToggleWidth = () => {
    updateToggle(root, false, chips.length, true);
    toggle.style.visibility = 'hidden';
    const width = toggle.getBoundingClientRect().width;
    toggle.style.visibility = '';
    updateToggle(root, false, 0, false);
    return width;
  };

  let usedWidth = 0;
  let visibleCount = 0;

  for (let index = 0; index < chipWidths.length; index += 1) {
    const nextWidth = chipWidths[index] + (visibleCount > 0 ? gap : 0);
    if (usedWidth + nextWidth <= availableWidth) {
      usedWidth += nextWidth;
      visibleCount += 1;
    } else {
      break;
    }
  }

  if (visibleCount === chips.length) {
    return;
  }

  const toggleWidth = measureToggleWidth();
  usedWidth = 0;
  visibleCount = 0;

  for (let index = 0; index < chipWidths.length; index += 1) {
    const remaining = chipWidths.length - (index + 1);
    const reservedWidth = remaining > 0 ? gap + toggleWidth : 0;
    const nextWidth = chipWidths[index] + (visibleCount > 0 ? gap : 0);

    if (usedWidth + nextWidth + reservedWidth <= availableWidth) {
      usedWidth += nextWidth;
      visibleCount += 1;
    } else {
      break;
    }
  }

  chips.forEach((chip, index) => {
    chip.style.display = index < visibleCount ? '' : 'none';
  });

  updateToggle(root, false, chips.length - visibleCount, true);
}

function layout(root: HTMLElement, expanded: boolean) {
  setExpanded(root, expanded);

  if (expanded) {
    showAllChips(root);
    return;
  }

  collapseToFit(root);
}

export const OverflowChipList: Hook<OverflowChipListState> = {
  mounted() {
    this.__overflowChipListExpanded = false;

    this.__overflowChipListClickHandler = (event: Event) => {
      const target = event.target;

      if (!(target instanceof Element)) {
        return;
      }

      const toggle = target.closest<HTMLElement>('[data-overflow-toggle]');
      if (!toggle || !this.el.contains(toggle)) {
        return;
      }

      event.preventDefault();
      this.__overflowChipListExpanded = !(this.__overflowChipListExpanded ?? false);
      layout(this.el as HTMLElement, this.__overflowChipListExpanded);
    };

    this.el.addEventListener('click', this.__overflowChipListClickHandler);

    this.__overflowChipListResizeHandler = () => {
      scheduleLayout(this.el as HTMLElement, this.__overflowChipListExpanded ?? false);
    };

    window.addEventListener('resize', this.__overflowChipListResizeHandler);
    layout(this.el as HTMLElement, false);
  },

  updated() {
    layout(this.el as HTMLElement, this.__overflowChipListExpanded ?? false);
  },

  destroyed() {
    if (this.__overflowChipListClickHandler) {
      this.el.removeEventListener('click', this.__overflowChipListClickHandler);
    }

    if (this.__overflowChipListResizeHandler) {
      window.removeEventListener('resize', this.__overflowChipListResizeHandler);
    }

    if (this.__overflowChipListResizeRaf != null) {
      cancelAnimationFrame(this.__overflowChipListResizeRaf);
    }

    this.__overflowChipListClickHandler = null;
    this.__overflowChipListResizeHandler = null;
    this.__overflowChipListResizeRaf = null;
  },
};
