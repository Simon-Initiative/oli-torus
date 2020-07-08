import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { ModelEditorProps, Choice } from '../schema';
import { Response, RichText } from '../../types';
import { Description } from 'components/misc/Description';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import { CloseButton } from 'components/misc/CloseButton';
import { ProjectSlug } from 'data/types';

interface ChoicesProps extends ModelEditorProps {
  onAddChoice: () => void;
  onEditChoice: (id: string, content: RichText) => void;
  onRemoveChoice: (id: string) => void;
  projectSlug: ProjectSlug;
}
export const Choices = ({ onAddChoice, onEditChoice, onRemoveChoice, editMode, model, projectSlug }:
  ChoicesProps) => {

  const { authoring: { parts }, choices } = model;
  const isCorrect = (response: Response) => response.score === 1;

  const correctChoice = choices.reduce((correct, choice) => {

    const responseMatchesChoice = (response: Response, choice: Choice) =>
      response.rule === `input like {${choice.id}}`;
    if (correct) return correct;

    if (parts[0].responses.find(response =>
      responseMatchesChoice(response, choice)
      && isCorrect(response))) return choice;

    throw new Error('Correct choice could not be found:' + JSON.stringify(choices));
  });

  const incorrectChoices = choices.filter(choice => choice.id !== correctChoice.id);

  return (
    <div className="my-5">
      <Heading title="Answer Choices"
        subtitle="One correct answer choice and as many incorrect answer choices as you like." id="choices" />
      <Description>
        <IconCorrect /> Correct Choice
      </Description>
      <RichTextEditor
        className="mb-3"
        projectSlug={projectSlug}
        key="correct" editMode={editMode} text={correctChoice.content}
        onEdit={content => onEditChoice(correctChoice.id, content)} />
      {incorrectChoices.map((choice, index) =>
        <React.Fragment key={choice.id}>
          <Description>
            <IconIncorrect /> Incorrect Choice {index + 1}
          </Description>
          <div className="d-flex mb-3">
            <RichTextEditor
              className="flex-fill"
              projectSlug={projectSlug}
              key={choice.id} editMode={editMode} text={choice.content}
              onEdit={content => onEditChoice(choice.id, content)}/>
            <CloseButton
              className="pl-3 pr-1"
              onClick={() => onRemoveChoice(choice.id)}
              editMode={editMode} />
          </div>
        </React.Fragment>,
      )}
      <button
        className="btn btn-sm btn-primary my-2"
        disabled={!editMode}
        onClick={onAddChoice}>Add incorrect answer choice
      </button>
    </div>
  );
};
