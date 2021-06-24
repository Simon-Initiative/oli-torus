import { WriterContext } from 'data/content/writers/context';
import React from 'react';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { Choice, ChoiceId } from 'components/activities/types';
import './ChoicesDelivery.scss';

interface Props {
  choices: Choice[];
  selected: ChoiceId[];
  context: WriterContext;
  onSelect: (id: ChoiceId) => void;
  isEvaluated: boolean;
  unselectedIcon: React.ReactNode;
  selectedIcon: React.ReactNode;
}
export const ChoicesDelivery: React.FC<Props> = ({
  choices,
  selected,
  context,
  onSelect,
  isEvaluated,
  unselectedIcon,
  selectedIcon,
}) => {
  const isSelected = (choiceId: ChoiceId) => !!selected.find((s) => s === choiceId);
  return (
    <div className="choices__container" aria-label="answer choices">
      {choices.map((choice, index) => (
        <div
          key={choice.id}
          aria-label={`choice ${index + 1}`}
          onClick={isEvaluated ? undefined : () => onSelect(choice.id)}
          className={`choices__choice-row ${isSelected(choice.id) ? 'selected' : ''}`}
        >
          <div className="choices__choice-wrapper">
            <label className="choices__choice-label" htmlFor={`choice-${index}`}>
              <div className="d-flex align-items-center flex-shrink-1">
                {isSelected(choice.id) ? selectedIcon : unselectedIcon}
                <div className="choices__choice-content">
                  <HtmlContentModelRenderer text={choice.content} context={context} />
                </div>
              </div>
            </label>
          </div>
        </div>
      ))}
    </div>
  );
};
