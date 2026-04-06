type ResizeContainer = HTMLElement & {
  dataset: DOMStringMap & {
    dashboardSectionId?: string;
    dashboardSectionSplit?: string;
  };
};

const MIN_SPLIT = 30;
const MAX_SPLIT = 70;
const MIN_TILE_WIDTH_PX = 560;
const NARROW_TILE_WIDTH_PX = 700;
const DEFAULT_PRIMARY_SPLIT = 43;
const DESKTOP_MEDIA_QUERY = '(min-width: 1280px)';

function clampSplit(split: number): number {
  return Math.min(MAX_SPLIT, Math.max(MIN_SPLIT, split));
}

function readSplit(container: ResizeContainer): number {
  const split = Number.parseInt(container.dataset.dashboardSectionSplit ?? '', 10);
  return Number.isFinite(split) ? clampSplit(split) : 43;
}

function applySplit(container: ResizeContainer, split: number) {
  container.style.setProperty('--dashboard-section-split', `${split}%`);
  container.dataset.dashboardSectionSplit = String(split);
}

function applyLayoutMode(container: ResizeContainer, split: number) {
  const tilePanes = Array.from(
    container.querySelectorAll<HTMLElement>('[data-dashboard-section-tile-pane]'),
  );
  const resizeHandles = Array.from(
    container.querySelectorAll<HTMLElement>('[data-dashboard-section-resize-handle]'),
  );
  const containerWidth = container.getBoundingClientRect().width;
  const leftWidth = (containerWidth * split) / 100;
  const rightWidth = containerWidth - leftWidth;
  const collapsedPaneIndex =
    leftWidth < MIN_TILE_WIDTH_PX ? 0 : rightWidth < MIN_TILE_WIDTH_PX ? 1 : null;
  const shouldStack =
    !window.matchMedia(DESKTOP_MEDIA_QUERY).matches ||
    leftWidth < MIN_TILE_WIDTH_PX ||
    rightWidth < MIN_TILE_WIDTH_PX;

  if (shouldStack) {
    const topPaneIndex = collapsedPaneIndex === 0 ? 1 : 0;
    const bottomPaneIndex = collapsedPaneIndex === 0 ? 0 : 1;
    const topPaneWidth = topPaneIndex === 0 ? split : 100 - split;
    const bottomPaneWidth =
      bottomPaneIndex === 0 ? DEFAULT_PRIMARY_SPLIT : 100 - DEFAULT_PRIMARY_SPLIT;

    container.style.gridTemplateColumns = 'minmax(0, 1fr)';
    container.style.columnGap = '';
    container.style.rowGap = '1rem';
    container.dataset.dashboardSectionLayoutMode = 'stacked';
    resizeHandles.forEach((resizeHandle) => {
      resizeHandle.classList.remove('invisible', 'pointer-events-none');
      resizeHandle.style.display = 'flex';
    });

    tilePanes.forEach((tilePane, index) => {
      const isTopPane = index === topPaneIndex;
      const width = isTopPane ? topPaneWidth : bottomPaneWidth;

      tilePane.classList.remove('xl:pr-2', 'xl:pl-2');
      tilePane.style.gridColumn = '1';
      tilePane.style.gridRow = isTopPane ? '1' : '2';
      tilePane.style.maxWidth = `${width}%`;
      tilePane.style.width = '100%';
      tilePane.style.justifySelf = 'start';
      tilePane.style.position = 'relative';
    });
  } else {
    container.style.gridTemplateColumns = `minmax(0, ${split}%) minmax(0, ${100 - split}%)`;
    container.style.columnGap = '0';
    container.style.rowGap = '';
    container.dataset.dashboardSectionLayoutMode = 'split';
    resizeHandles.forEach((resizeHandle) => {
      resizeHandle.classList.remove('invisible', 'pointer-events-none');
      resizeHandle.style.display = 'flex';
    });

    tilePanes.forEach((tilePane, index) => {
      tilePane.style.gridColumn = String(index + 1);
      tilePane.style.gridRow = '1';
      tilePane.style.maxWidth = '';
      tilePane.style.width = '';
      tilePane.style.justifySelf = '';
      tilePane.style.position = 'relative';

      if (index === 0) {
        tilePane.classList.add('xl:pr-2');
        tilePane.classList.remove('xl:pl-2');
      } else {
        tilePane.classList.add('xl:pl-2');
        tilePane.classList.remove('xl:pr-2');
      }
    });
  }

  positionResizeHandles(container, tilePanes, resizeHandles);
}

function positionResizeHandles(
  container: ResizeContainer,
  tilePanes: HTMLElement[],
  resizeHandles: HTMLElement[],
) {
  const containerRect = container.getBoundingClientRect();
  const isSplitLayout = container.dataset.dashboardSectionLayoutMode === 'split';

  resizeHandles.forEach((resizeHandle) => {
    const paneIndex = Number.parseInt(resizeHandle.dataset.paneIndex ?? '', 10);
    const tilePane = tilePanes[paneIndex];

    if (!tilePane) {
      resizeHandle.style.display = 'none';
      return;
    }

    // Position against the visible tile card border, not the pane wrapper, because
    // the pane includes responsive padding/gutter that varies by tile and layout mode.
    const tileSurface =
      tilePane.firstElementChild instanceof HTMLElement ? tilePane.firstElementChild : tilePane;
    const surfaceRect = tileSurface.getBoundingClientRect();
    const widthMode =
      isSplitLayout && surfaceRect.width < NARROW_TILE_WIDTH_PX ? 'narrow' : 'normal';
    const left = surfaceRect.right - containerRect.left;
    const top = surfaceRect.top - containerRect.top + surfaceRect.height / 2;

    tileSurface.dataset.dashboardWidthMode = widthMode;
    tileSurface
      .querySelectorAll<HTMLElement>('[data-dashboard-width-aware]')
      .forEach((element) => {
        element.dataset.dashboardWidthMode = widthMode;
      });

    resizeHandle.style.display = 'block';
    resizeHandle.style.left = `${left}px`;
    resizeHandle.style.top = `${top}px`;
    resizeHandle.style.height = `${surfaceRect.height}px`;
  });
}

export const DashboardTileGroupResize = {
  mounted() {
    const container = this.el as ResizeContainer;
    const resizeHandles = Array.from(
      container.querySelectorAll<HTMLElement>('[data-dashboard-section-resize-handle]'),
    );
    const sectionId = container.dataset.dashboardSectionId ?? '';
    const desktopQuery = window.matchMedia(DESKTOP_MEDIA_QUERY);

    if (resizeHandles.length === 0 || !sectionId) {
      return;
    }

    const syncLayout = (split: number) => {
      applySplit(container, split);
      applyLayoutMode(container, split);
    };

    syncLayout(readSplit(container));

    let activePointerId: number | null = null;
    let draftSplit = readSplit(container);
    let dragOffsetPx = 0;

    const cleanup = (commit: boolean) => {
      if (activePointerId === null) {
        return;
      }

      document.body.classList.remove('cursor-col-resize', 'select-none');

      if (commit) {
        this.pushEvent('dashboard_section_resized', {
          section_id: sectionId,
          split: draftSplit,
        });
      } else {
        syncLayout(readSplit(container));
      }

      activePointerId = null;
      dragOffsetPx = 0;
    };

    const onPointerMove = (event: PointerEvent) => {
      if (event.pointerId !== activePointerId) {
        return;
      }

      const rect = container.getBoundingClientRect();

      if (rect.width <= 0) {
        return;
      }

      const pointerPercent = Math.round(
        ((event.clientX - dragOffsetPx - rect.left) / rect.width) * 100,
      );
      const nextSplit = clampSplit(pointerPercent);

      draftSplit = nextSplit;
      syncLayout(nextSplit);
    };

    const onPointerUp = (event: PointerEvent) => {
      if (event.pointerId === activePointerId) {
        cleanup(true);
      }
    };

    const onPointerCancel = (event: PointerEvent) => {
      if (event.pointerId === activePointerId) {
        cleanup(false);
      }
    };

    resizeHandles.forEach((resizeHandle) => {
      resizeHandle.addEventListener('pointerdown', (event: PointerEvent) => {
        if (!desktopQuery.matches) {
          return;
        }

        const rect = container.getBoundingClientRect();
        const currentSplit = readSplit(container);
        const dividerX = rect.left + (rect.width * currentSplit) / 100;

        event.preventDefault();
        activePointerId = event.pointerId;
        dragOffsetPx = event.clientX - dividerX;
        draftSplit = currentSplit;

        document.body.classList.add('cursor-col-resize', 'select-none');
      });
    });

    window.addEventListener('pointermove', onPointerMove);
    window.addEventListener('pointerup', onPointerUp);
    window.addEventListener('pointercancel', onPointerCancel);

    this.cleanup = () => {
      window.removeEventListener('pointermove', onPointerMove);
      window.removeEventListener('pointerup', onPointerUp);
      window.removeEventListener('pointercancel', onPointerCancel);
      document.body.classList.remove('cursor-col-resize', 'select-none');
    };
  },

  updated() {
    const container = this.el as ResizeContainer;
    const split = readSplit(container);
    applySplit(container, split);
    applyLayoutMode(container, split);
  },

  destroyed() {
    this.cleanup?.();
  },
};
