import React, { useCallback, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import AccordionAuthorModal from '../../../../../components/parts/janus-accordion/AccordionAuthorModal';
import { normalizeSections } from '../../../../../components/parts/janus-accordion/accordion-util';
import {
  AccordionModel,
  AccordionSection,
} from '../../../../../components/parts/janus-accordion/schema';
import { selectCurrentActivityTree } from '../../../../delivery/store/features/groups/selectors/deck';
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

export const AccordionManageEditor: React.FC<CustomFieldProps> = ({
  disabled,
  readonly,
  onBlur,
  id,
}) => {
  const dispatch = useDispatch();
  const [editorOpen, setEditorOpen] = useState(false);
  const currentPartSelection = useSelector(selectCurrentSelection);
  const activityTree = useSelector(selectCurrentActivityTree);

  const context = useMemo(
    () => getPartContext(activityTree, currentPartSelection),
    [activityTree, currentPartSelection],
  );

  const custom = (context?.part?.custom || {}) as AccordionModel;
  const sections = normalizeSections(custom.sections);

  const summary =
    sections.length === 0
      ? 'No sections yet'
      : `${sections.length} section${sections.length !== 1 ? 's' : ''}`;

  const handleOpen = useCallback(() => setEditorOpen(true), []);

  const handleClose = useCallback(() => {
    onBlur(id, null);
    setEditorOpen(false);
  }, [id, onBlur]);

  const handleSave = useCallback(
    (updatedSections: AccordionSection[]) => {
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
              sections: updatedSections,
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
      <label className="form-label">Manage Sections</label>
      <p className="mb-2">{summary}</p>
      <button
        className="btn btn-primary btn-block"
        type="button"
        disabled={disabled || readonly || editorOpen}
        onClick={handleOpen}
      >
        Manage Sections
      </button>
      {editorOpen && context && (
        <AccordionAuthorModal
          show={editorOpen}
          sections={sections}
          onSave={handleSave}
          onCancel={handleClose}
        />
      )}
    </div>
  );
};
