import React, { useState } from 'react';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { ChoiceIdsToResponseId, ModelEditorProps, TargetedCATA } from '../schema';
import { Description } from 'components/misc/Description';
import { IconIncorrect } from 'components/misc/Icons';
import { ProjectSlug } from 'data/types';
import { getChoiceIds, getResponse, getResponseId, getTargetedResponses } from '../utils';
import { Typeahead } from 'react-bootstrap-typeahead';
import { ChoiceId, ResponseId, RichText } from 'components/activities/types';
import { CloseButton } from 'components/misc/CloseButton';

interface Props extends ModelEditorProps {
  onEditResponseFeedback: (id: string, content: RichText) => void;
  onAddTargetedFeedback: () => void;
  onRemoveTargetedFeedback: (responseId: ResponseId) => void;
  onEditTargetedFeedbackChoices: (responseId: ResponseId, choiceIds: ChoiceId[]) => void;
  model: TargetedCATA;
  projectSlug: ProjectSlug;
}

interface Option {
  id: string;
  label: string;
}
type OptionMap = {[id: string]: Option[]};

export const TargetedFeedback = (props: Props) => {
  const { model, editMode, projectSlug, onEditResponseFeedback, onAddTargetedFeedback,
    onRemoveTargetedFeedback, onEditTargetedFeedbackChoices } = props;

  const createSelection = (assocs: ChoiceIdsToResponseId[]) =>
    assocs.reduce((acc, assoc) => {
      acc[getResponseId(assoc)] = toOptions(getChoiceIds(assoc));
      return acc;
    }, {} as OptionMap);

  const toOptions = (choiceIds: ChoiceId[]) =>
    choiceIds.map(id => ({
      id,
      label: (model.choices.findIndex(choice => choice.id === id) + 1).toString(),
    }));

  const allChoiceOptions = toOptions(model.choices.map(choice => choice.id));
  const selected = createSelection(model.authoring.targeted);

  return (
    <>
      {model.authoring.targeted.map((assoc) => {
        const response = getResponse(model, getResponseId(assoc));
        return (
          <div className="mb-3" key={response.id}>
            <Description>
              <IconIncorrect /> Feedback for Incorrect Combination
              <Typeahead
                id={response.id}
                disabled={!props.editMode}
                placeholder="Select choices..."
                options={allChoiceOptions}
                selected={selected[response.id]}
                selectHintOnEnter
                multiple
                onChange={(selection) => onEditTargetedFeedbackChoices(
                    response.id, selection.map(s => s.id))}
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
          </div>
        );
      })}
        <button
          className="btn btn-sm btn-primary my-2"
          disabled={!editMode}
          onClick={onAddTargetedFeedback}>Add targeted feedback
        </button>
    </>
  );
};
