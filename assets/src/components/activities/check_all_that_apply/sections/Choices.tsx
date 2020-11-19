import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { ModelEditorProps, Choice } from '../schema';
import { Response, RichText } from '../../types';
import { Description } from 'components/misc/Description';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import { CloseButton } from 'components/misc/CloseButton';
import { ProjectSlug } from 'data/types';
import styled from 'styled-components';
import { isCorrect } from 'components/activities/check_all_that_apply/utils';

const ToggleCorrect = styled.button`
  border: none;
  background: none;
`;

interface Props extends ModelEditorProps {
  onAddChoice: () => void;
  onEditChoiceContent: (id: string, content: RichText) => void;
  onToggleChoiceCorrectness: (choice: Choice) => void;
  onRemoveChoice: (id: string) => void;
  projectSlug: ProjectSlug;
}
export const Choices = (props: Props) => {
  const { onAddChoice, onEditChoiceContent, onRemoveChoice, onToggleChoiceCorrectness,
    editMode, model, projectSlug } = props;

  // A cata has two responses: Correct and incorrect. When making choices correct,
  // add the ids to the correct response rule condition, and remove it from the incorrect?
  // Check if legacy -> need some way of enabling advanced feedback for specific matches
  // use ||

  const { authoring: { parts }, choices } = model;

  // One response will make to multiple choices that it corresponds to
  // eg. correct choice 1 -> resp1
  //     correct choice 2 -> resp1
  //     incorrect choice -> resp2


  // response with correct choice combination will be like `input like 13 && input like 14`
  // make sure the question engine creates the right "input" -> it will need to be a list

  const choicesWithResponses: [Choice, Response][] = choices.map((choice) => {
    const matchingResponse = parts[0].responses.find(response =>
      responseMatchesChoice(response, choice));

    if (!matchingResponse) {
      throw new Error('Matching response not found for choice: ' + JSON.stringify(choice));
    }

    return [choice, matchingResponse];
  });

  // get correct choices, incorrect choices
  // when toggling, updateResponseCorrectness(correctChoices, incorrectChoices)
  // there are two responses, so we update both with the new lists

  // correctness could be extended to partial credit and advanced scoring for specific
  // combinations of choices. For simplicity, we're sticking to a simple correct/incorrect model
  // for now.


  return (
    <div className="my-5">
      <Heading title="Answer Choices"
        subtitle="One correct answer choice and as many incorrect answer choices as you like." id="choices" />
      {choicesWithResponses.map(([choice, response], index) =>
        <div key={choice.id} className="d-flex align-items-center mb-3">
          <div className="material-icons">
            <ToggleCorrect onClick={() => onToggleChoiceCorrectness(choice)}>
              {isCorrect(response) ? 'check_circle' : 'check_circle_outline'}
            </ToggleCorrect>
          </div>
          <div className="d-flex" style={{ flex: 1 }}>
            <RichTextEditor
              className="flex-fill"
              projectSlug={projectSlug}
              editMode={editMode} text={choice.content}
              onEdit={content => onEditChoiceContent(choice.id, content)} />
            <CloseButton
              className="pl-3 pr-1"
              onClick={() => onRemoveChoice(choice.id)}
              editMode={editMode} />
          </div>
        </div>)}
      <button
        className="btn btn-sm btn-primary my-2"
        disabled={!editMode}
        onClick={onAddChoice}>Add answer choice
      </button>
    </div >
  );
};
