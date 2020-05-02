import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { ModelEditorProps, Feedback, Choice, RichText } from '../schema';
import { Description } from 'components/misc/Description';
import { IconCorrect } from 'components/misc/IconCorrect';
import { CloseButton } from 'components/misc/CloseButton';

interface ChoicesProps extends ModelEditorProps {
  onAddChoice: () => void;
  onEditChoice: (id: number, content: RichText) => void;
  onRemoveChoice: (id: number) => void;
}
export const Choices = ({ onAddChoice, onEditChoice, onRemoveChoice, editMode, model }:
  ChoicesProps) => {
  const { authoring: { feedback }, choices } = model;
  const isCorrect = (feedback: Feedback) => feedback.score === 1;

  const correctChoice = choices.reduce((correct, choice) => {
    const feedbackMatchesChoice = (feedback: Feedback, choice: Choice) =>
      feedback.match === choice.id;
    if (correct) return correct;
    if (feedback.find(feedback =>
      feedbackMatchesChoice(feedback, choice) && isCorrect(feedback))) return choice;
    throw new Error('Correct choice could not be found:' + JSON.stringify(choices));
  });

  const incorrectChoices = choices.filter(choice => choice.id !== correctChoice.id);

  return (
    <div style={{ margin: '2rem 0' }}>
      <Heading title="Answer Choices"
        subtitle="One correct answer choice and as many incorrect answer choices as you like." id="choices" />
      <RichTextEditor editMode={editMode} text={correctChoice.content}
        onEdit={content => onEditChoice(correctChoice.id, content)}>
        <Description><IconCorrect /> Correct Answer</Description>
      </RichTextEditor>
      {incorrectChoices.map((choice, index) =>
        <RichTextEditor key={choice.id} editMode={editMode} text={choice.content}
          onEdit={content => onEditChoice(choice.id, content)}>
          <Description>
            <CloseButton onClick={() => onRemoveChoice(choice.id)}
              editMode={editMode} />
            Common Misconception {index + 1}
          </Description>
        </RichTextEditor>)}
      <button
        disabled={!editMode}
        onClick={onAddChoice}
        className="btn btn-primary">Add incorrect answer choice
      </button>
    </div>
  );
};
