type SectionElement = HTMLElement & {
  dataset: DOMStringMap & {
    dashboardSectionId?: string;
    reorderEvent?: string;
  };
};

// Shared drag state is kept at module scope so sibling section hooks can
// coordinate hover/drop behavior while a drag gesture is in progress.
let draggedSectionId: string | null = null;

// Keyboard reorder applies a local DOM move before the LiveView patch arrives.
// Track the moved section so focus can be restored on the same handle after update.
let pendingKeyboardFocusSectionId: string | null = null;

function orderedSectionIds(container: HTMLElement): string[] {
  return Array.from(container.querySelectorAll<SectionElement>('[data-dashboard-section-id]'))
    .map((section) => section.dataset.dashboardSectionId)
    .filter(
      (sectionId): sectionId is string => typeof sectionId === 'string' && sectionId.length > 0,
    );
}

function moveSection(sectionIds: string[], sectionId: string, offset: -1 | 1): string[] {
  const sourceIndex = sectionIds.indexOf(sectionId);
  const targetIndex = sourceIndex + offset;

  if (sourceIndex === -1 || targetIndex < 0 || targetIndex >= sectionIds.length) {
    return sectionIds;
  }

  const nextOrder = [...sectionIds];
  const [movedSection] = nextOrder.splice(sourceIndex, 1);
  nextOrder.splice(targetIndex, 0, movedSection);

  return nextOrder;
}

export function buildDroppedSectionOrder(
  sectionIds: string[],
  draggedSectionId: string,
  targetSectionId: string,
): string[] {
  if (draggedSectionId === targetSectionId) {
    return sectionIds;
  }

  const draggedIndex = sectionIds.indexOf(draggedSectionId);
  const targetIndex = sectionIds.indexOf(targetSectionId);

  if (draggedIndex === -1 || targetIndex === -1) {
    return sectionIds;
  }

  const nextOrder = [...sectionIds];
  // Drop is modeled as a swap: the dragged section takes the target position,
  // and the target section fills the dragged section's previous position.
  nextOrder[draggedIndex] = targetSectionId;
  nextOrder[targetIndex] = draggedSectionId;

  return nextOrder;
}

function applySectionOrder(container: HTMLElement, sectionIds: string[]) {
  const sectionsById = new Map(
    Array.from(container.querySelectorAll<SectionElement>('[data-dashboard-section-id]')).map(
      (section) => [section.dataset.dashboardSectionId, section],
    ),
  );

  sectionIds.forEach((sectionId) => {
    const section = sectionsById.get(sectionId);

    if (section) {
      container.appendChild(section);
    }
  });
}

function clearDragState(container: HTMLElement) {
  container
    .querySelectorAll<HTMLElement>('[data-dashboard-section-id]')
    .forEach((section) =>
      section.classList.remove(
        'border-Border-border-bold-hover',
        'bg-Surface-surface-secondary',
        'shadow-[0px_12px_24px_0px_rgba(0,52,99,0.18)]',
        'scale-[0.995]',
      ),
    );
}

export const DashboardSectionChrome = {
  mounted() {
    const section = this.el as SectionElement;
    const handle = section.querySelector<HTMLElement>('[data-section-handle]');
    const container = section.parentElement as HTMLElement | null;
    const reorderEvent = section.dataset.reorderEvent ?? 'dashboard_sections_reordered';

    if (!handle || !container) {
      return;
    }

    handle.addEventListener('dragstart', (event: DragEvent) => {
      draggedSectionId = section.dataset.dashboardSectionId ?? null;
      section.classList.add(
        'border-Border-border-bold-hover',
        'bg-Surface-surface-secondary',
        'shadow-[0px_12px_24px_0px_rgba(0,52,99,0.18)]',
        'scale-[0.995]',
      );

      if (event.dataTransfer && draggedSectionId) {
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', draggedSectionId);
      }
    });

    handle.addEventListener('dragend', () => {
      draggedSectionId = null;
      section.classList.remove('opacity-70');
      clearDragState(container);
    });

    section.addEventListener('dragover', (event: DragEvent) => {
      if (!draggedSectionId || draggedSectionId === section.dataset.dashboardSectionId) {
        return;
      }

      event.preventDefault();
    });

    section.addEventListener('dragenter', (event: DragEvent) => {
      if (!draggedSectionId || draggedSectionId === section.dataset.dashboardSectionId) {
        return;
      }

      event.preventDefault();
      clearDragState(container);
      section.classList.add('border-Border-border-bold-hover', 'bg-Surface-surface-secondary');
    });

    section.addEventListener('dragleave', (event: DragEvent) => {
      if (event.currentTarget === event.target) {
        section.classList.remove('border-Border-border-bold-hover', 'bg-Surface-surface-secondary');
      }
    });

    section.addEventListener('drop', (event: DragEvent) => {
      if (!draggedSectionId || draggedSectionId === section.dataset.dashboardSectionId) {
        return;
      }

      event.preventDefault();

      const currentOrder = orderedSectionIds(container);
      const targetSectionId = section.dataset.dashboardSectionId ?? '';

      if (!targetSectionId) {
        clearDragState(container);
        return;
      }

      const nextOrder = buildDroppedSectionOrder(currentOrder, draggedSectionId, targetSectionId);

      if (nextOrder.join('|') === currentOrder.join('|')) {
        clearDragState(container);
        return;
      }

      applySectionOrder(container, nextOrder);
      clearDragState(container);
      this.pushEvent(reorderEvent, { section_ids: nextOrder });
    });

    handle.addEventListener('keydown', (event: KeyboardEvent) => {
      // Match the Remix-style keyboard affordance: Shift+Arrow moves the focused
      // section one slot at a time without entering a separate "grabbed" mode.
      if (!event.shiftKey || (event.key !== 'ArrowUp' && event.key !== 'ArrowDown')) {
        return;
      }

      event.preventDefault();

      const sectionId = section.dataset.dashboardSectionId;

      if (!sectionId) {
        return;
      }

      const currentOrder = orderedSectionIds(container);
      const nextOrder = moveSection(currentOrder, sectionId, event.key === 'ArrowUp' ? -1 : 1);

      if (nextOrder.join('|') === currentOrder.join('|')) {
        return;
      }

      pendingKeyboardFocusSectionId = sectionId;
      applySectionOrder(container, nextOrder);
      handle.focus({ preventScroll: true });
      this.pushEvent(reorderEvent, { section_ids: nextOrder });
    });
  },

  updated() {
    const section = this.el as SectionElement;

    if (section.dataset.dashboardSectionId !== pendingKeyboardFocusSectionId) {
      return;
    }

    const handle = section.querySelector<HTMLElement>('[data-section-handle]');

    if (handle) {
      // LiveView may patch the section node after the local reorder. Re-focus
      // the current handle so keyboard users do not lose their place.
      handle.focus({ preventScroll: true });
    }

    pendingKeyboardFocusSectionId = null;
  },
};
