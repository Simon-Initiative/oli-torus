import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/content/RichTextEditor';
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

  const choicesWithResponses: [Choice, Response][] = choices.map((choice) => {
    const responseMatchesChoice = (response: Response, choice: Choice) =>
      response.rule === `input like {${choice.id}}`;

    const matchingResponse = parts[0].responses.find(response =>
      responseMatchesChoice(response, choice));

    if (!matchingResponse) {
      throw new Error('Matching response not found for choice: ' + JSON.stringify(choice));
    }

    return [choice, matchingResponse];
  });

  const isCorrect = (response: Response) => response.score === 1;
  const checkIcon = (isCorrect: boolean) => isCorrect ? 'check_circle' : 'check_circle_outline';
  const toggleCorrectnessButton = <button className="list-unstyled" style={{}}>

  </button>

  return (
    <div className="my-5">
      <Heading title="Answer Choices"
        subtitle="One correct answer choice and as many incorrect answer choices as you like." id="choices" />
      {choicesWithResponses.map(([choice, response], index) =>
        <React.Fragment key={choice.id}>
          <div className="d-flex">
            <div className="material-icons">{checkIcon(isCorrect(response))}</div>
            <div className="d-flex mb-3" style={{ flex: 1 }}>
              <RichTextEditor
                className="flex-fill"
                projectSlug={projectSlug}
                editMode={editMode} text={choice.content}
                onEdit={content => onEditChoice(choice.id, content)} />
              <CloseButton
                className="pl-3 pr-1"
                onClick={() => onRemoveChoice(choice.id)}
                editMode={editMode} />
            </div>
          </div>
        </React.Fragment>)}
      <button
        className="btn btn-sm btn-primary my-2"
        disabled={!editMode}
        onClick={onAddChoice}>Add answer choice
      </button>
    </div >
  );
};
