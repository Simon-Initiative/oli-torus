import type { Hook } from 'phoenix_live_view/assets/js/types/view_hook';

type OverflowChipListState = {
  __overflowChipListExpanded?: boolean;
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

function showAllChips(root: HTMLElement) {
  chipElements(root).forEach((chip) => {
    chip.style.display = '';
  });

  const toggle = toggleElement(root);
  if (toggle) {
    toggle.classList.add('hidden');
    toggle.classList.remove('inline-flex');
  }
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

  toggle.classList.add('hidden');
  toggle.classList.remove('inline-flex');

  const availableWidth = root.clientWidth;
  const gap = gapSize(root);

  if (availableWidth <= 0 || chips.length === 0) {
    return;
  }

  const chipWidths = chips.map((chip) => chip.getBoundingClientRect().width);

  const measureToggleWidth = () => {
    toggle.classList.remove('hidden');
    toggle.classList.add('inline-flex');
    toggle.style.visibility = 'hidden';
    const width = toggle.getBoundingClientRect().width;
    toggle.style.visibility = '';
    toggle.classList.add('hidden');
    toggle.classList.remove('inline-flex');
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

  if (visibleCount < 1) {
    visibleCount = 1;
  }

  chips.forEach((chip, index) => {
    chip.style.display = index < visibleCount ? '' : 'none';
  });

  toggle.classList.remove('hidden');
  toggle.classList.add('inline-flex');
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

    const toggle = toggleElement(this.el as HTMLElement);
    toggle?.addEventListener('click', () => {
      this.__overflowChipListExpanded = true;
      layout(this.el as HTMLElement, true);
    });

    this.__overflowChipListResizeHandler = () => {
      if (this.__overflowChipListResizeRaf != null) {
        cancelAnimationFrame(this.__overflowChipListResizeRaf);
      }

      this.__overflowChipListResizeRaf = requestAnimationFrame(() => {
        this.__overflowChipListResizeRaf = null;
        layout(this.el as HTMLElement, this.__overflowChipListExpanded ?? false);
      });
    };

    window.addEventListener('resize', this.__overflowChipListResizeHandler);
    layout(this.el as HTMLElement, false);
  },

  updated() {
    layout(this.el as HTMLElement, this.__overflowChipListExpanded ?? false);
  },

  destroyed() {
    if (this.__overflowChipListResizeHandler) {
      window.removeEventListener('resize', this.__overflowChipListResizeHandler);
    }

    if (this.__overflowChipListResizeRaf != null) {
      cancelAnimationFrame(this.__overflowChipListResizeRaf);
    }

    this.__overflowChipListResizeHandler = null;
    this.__overflowChipListResizeRaf = null;
  },
};
