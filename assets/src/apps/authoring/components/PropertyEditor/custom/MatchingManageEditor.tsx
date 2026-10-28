import React, { useCallback, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import MatchingAuthorModal from '../../../../../components/parts/janus-matching/MatchingAuthorModal';
import { normalizeMatchingItemsForSave } from '../../../../../components/parts/janus-matching/matching-util';
import { MatchingModel } from '../../../../../components/parts/janus-matching/schema';
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

export const MatchingManageEditor: React.FC<CustomFieldProps> = ({
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

  const custom = (context?.part?.custom || {}) as MatchingModel;
  const column1Items = custom.column1Items || [];
  const column2Items = custom.column2Items || [];
  const matchCount = Object.values(custom.correctMatches || {}).reduce(
    (sum, targets) => sum + (targets?.length || 0),
    0,
  );

  const summary =
    column1Items.length === 0 && column2Items.length === 0
      ? 'No items yet'
      : `${column1Items.length} + ${column2Items.length} items · ${matchCount} match${
          matchCount !== 1 ? 'es' : ''
        }`;

  const handleOpen = useCallback(() => setEditorOpen(true), []);

  const handleClose = useCallback(() => {
    onBlur(id, null);
    setEditorOpen(false);
  }, [id, onBlur]);

  const handleSave = useCallback(
    (
      snapshot: Pick<
        MatchingModel,
        'column1Title' | 'column2Title' | 'column1Items' | 'column2Items' | 'correctMatches'
      >,
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
              column1Title: snapshot.column1Title,
              column2Title: snapshot.column2Title,
              column1Items: normalizeMatchingItemsForSave(snapshot.column1Items),
              column2Items: normalizeMatchingItemsForSave(snapshot.column2Items),
              correctMatches: snapshot.correctMatches,
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
      <label className="form-label">Manage Matching</label>
      <p className="mb-2">{summary}</p>
      <button
        className="btn btn-primary btn-block"
        type="button"
        disabled={disabled || readonly || editorOpen}
        onClick={handleOpen}
      >
        Manage Matching
      </button>
      {editorOpen && context && (
        <MatchingAuthorModal
          show={editorOpen}
          model={{
            column1Title: custom.column1Title || 'Column 1',
            column2Title: custom.column2Title || 'Column 2',
            column1Items: custom.column1Items || [],
            column2Items: custom.column2Items || [],
            correctMatches: custom.correctMatches || {},
            themeColor: custom.themeColor,
          }}
          projectSlug={projectSlug}
          onSave={handleSave}
          onCancel={handleClose}
        />
      )}
    </div>
  );
};
