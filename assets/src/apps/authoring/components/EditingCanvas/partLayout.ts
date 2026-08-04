const NUMERIC_PART_LAYOUT_FIELDS = ['x', 'y', 'width', 'height', 'cardHeight', 'z'] as const;

export const pickNumericPartLayout = (dragData: Record<string, unknown> | null | undefined) =>
  NUMERIC_PART_LAYOUT_FIELDS.reduce<Record<string, number>>((layout, field) => {
    const value = dragData?.[field];

    if (typeof value === 'number') {
      layout[field] = value;
    }

    return layout;
  }, {});

export const buildPartLayoutUpdatePayload = (
  activityId: string,
  partId: string,
  dragData: Record<string, unknown> | null | undefined,
) => ({
  activityId,
  partId,
  changes: { custom: pickNumericPartLayout(dragData) },
  mergeChanges: true,
});
