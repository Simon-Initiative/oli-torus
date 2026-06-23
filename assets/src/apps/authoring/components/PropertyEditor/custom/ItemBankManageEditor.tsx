import React, { useCallback, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import ItemBankAuthorModal from '../../../../../components/parts/janus-item-bank/ItemBankAuthorModal';
import { normalizeGroupingItemsForSave } from '../../../../../components/parts/janus-item-bank/grouping-util';
import { GroupingModel } from '../../../../../components/parts/janus-item-bank/schema';
import { selectCurrentActivityTree } from '../../../../delivery/store/features/groups/selectors/deck';
import { selectProjectSlug } from '../../../store/app/slice';
import { updatePart } from '../../../store/parts/actions/updatePart';
import { selectCurrentSelection } from '../../../store/parts/slice';

interface CustomFieldProps {
  id: string;
  value: null;
  disabled: boolean;
  readonly: boolean;
  onChange: (value: null) => void;
  onBlur: (id: string, value: null) => void;
}

const getPartContext = (activityTree: any[], partId: string) => {
  for (let i = 0; i < activityTree.length; i++) {
    const activity = activityTree[i];
    const part = activity.content?.partsLayout.find((p: any) => p.id === partId);
    if (part) {
      return { activity, part };
    }
  }
  return null;
};

export const ItemBankManageEditor: React.FC<CustomFieldProps> = ({
  disabled,
  readonly,
  onBlur,
  id,
}) => {
  const dispatch = useDispatch();
  const [editorOpen, setEditorOpen] = useState(false);
  const currentPartSelection = useSelector(selectCurrentSelection);
  const activityTree = useSelector(selectCurrentActivityTree);
  const projectSlug = useSelector(selectProjectSlug);

  const context = useMemo(
    () => getPartContext(activityTree, currentPartSelection),
    [activityTree, currentPartSelection],
  );

  const custom = (context?.part?.custom || {}) as GroupingModel;
  const items = custom.items || [];
  const categories = custom.categories || [];

  const summary =
    items.length === 0
      ? 'No items yet'
      : `${items.length} item${items.length !== 1 ? 's' : ''} · ${categories.length} categor${
          categories.length !== 1 ? 'ies' : 'y'
        }`;

  const handleOpen = useCallback(() => setEditorOpen(true), []);

  const handleClose = useCallback(() => {
    onBlur(id, null);
    setEditorOpen(false);
  }, [id, onBlur]);

  const handleSave = useCallback(
    (
      snapshot: Pick<GroupingModel, 'items' | 'categories' | 'layoutPlacements' | 'correctAnswer'>,
    ) => {
      if (!context?.activity?.id || !currentPartSelection || !context.part) {
        return;
      }
      const part = context.part;
      dispatch(
        updatePart({
          activityId: String(context.activity.id),
          partId: currentPartSelection,
          changes: {
            ...part,
            custom: {
              ...part.custom,
              items: normalizeGroupingItemsForSave(snapshot.items),
              categories: snapshot.categories,
              layoutPlacements: snapshot.layoutPlacements,
              correctAnswer: snapshot.correctAnswer,
            },
          },
          mergeChanges: false,
        }),
      );
      setEditorOpen(false);
      onBlur(id, null);
    },
    [context, currentPartSelection, dispatch, id, onBlur],
  );

  return (
    <div>
      <label className="form-label">Manage Item Bank</label>
      <p className="mb-2">{summary}</p>
      <button
        className="btn btn-primary btn-block"
        type="button"
        disabled={disabled || readonly || editorOpen}
        onClick={handleOpen}
      >
        Manage Item Bank
      </button>
      {editorOpen && context && (
        <ItemBankAuthorModal
          show={editorOpen}
          model={{
            items: custom.items || [],
            categories: custom.categories || [],
            layoutPlacements: custom.layoutPlacements || {},
            correctAnswer: custom.correctAnswer || {},
          }}
          projectSlug={projectSlug}
          onSave={handleSave}
          onCancel={handleClose}
        />
      )}
    </div>
  );
};
