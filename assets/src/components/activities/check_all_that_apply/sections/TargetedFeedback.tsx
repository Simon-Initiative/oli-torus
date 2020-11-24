import React, { useState } from 'react';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { ChoiceIdsToResponseId, ModelEditorProps, TargetedCATA } from '../schema';
import { Description } from 'components/misc/Description';
import { IconIncorrect } from 'components/misc/Icons';
import { ProjectSlug } from 'data/types';
import { getChoiceIds, getTargetedResponses } from '../utils';
import { Typeahead } from 'react-bootstrap-typeahead';
import { ChoiceId, ResponseId, RichText } from 'components/activities/types';
import { CloseButton } from 'components/misc/CloseButton';

interface Props extends ModelEditorProps {
  onEditResponseFeedback: (id: string, content: RichText) => void;
  onAddTargetedFeedback: () => void;
  onRemoveTargetedFeedback: (responseId: ResponseId) => void;
  onEditTargetedFeedbackChoices: (choiceIds: ChoiceId[]) => void;
  model: TargetedCATA;
  projectSlug: ProjectSlug;
}
export const TargetedFeedback = (props: Props) => {
  const { model, editMode, projectSlug, onEditResponseFeedback, onAddTargetedFeedback,
    onRemoveTargetedFeedback, onEditTargetedFeedbackChoices } = props;

  const getSelected = (assocs: ChoiceIdsToResponseId[]) =>
    assocs.map(assoc => toOptions(getChoiceIds(assoc)));

  const toOptions = (choiceIds: ChoiceId[]) =>
    choiceIds.map(id => ({ id, label: model.choices.findIndex(choice => choice.id === id) + 1 }));

  const [selected, setSelected] = useState(getSelected(model.authoring.targeted));

  return (
    <>
      {getTargetedResponses(model).map(response =>
        <div className="mb-3" key={response.id}>
          <Description>
            <IconIncorrect /> Feedback for Incorrect Combination
            <Typeahead
              options={toOptions(getChoiceIds())}
              selected={selected}
              multiple
              onChange={(selected) => {
                setSelected(Object.assign(selected, { [response.id]: selected }));
              }}
            />
          </Description>
          <div className="d-flex align-items-center" style={{ flex: 1 }}>
            <RichTextEditor projectSlug={projectSlug}
              className="flex-fill"
              editMode={editMode} text={response.feedback.content}
              onEdit={content => onEditResponseFeedback(response.id, content)}/>
            <CloseButton
              className="pl-3 pr-1"
              onClick={() => onRemoveTargetedFeedback(response.id)}
              editMode={editMode} />
          </div>
        </div>)}
        <button
          className="btn btn-sm btn-primary my-2"
          disabled={!editMode}
          onClick={onAddTargetedFeedback}>Add targeted feedback
        </button>
    </>
  );
};
