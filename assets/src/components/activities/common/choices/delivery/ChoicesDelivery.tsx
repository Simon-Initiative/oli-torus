import React, { useCallback } from 'react';
import { Choice, ChoiceId } from 'components/activities/types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { classNames } from 'utils/classNames';
import styles from './ChoicesDelivery.modules.scss';

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

  console.log("ChoicesDelivery: ");
  console.log(selected);

  const onClicked = useCallback(
    (choiceId: ChoiceId) => (event: React.MouseEvent) => {
      if (event.isDefaultPrevented()) {
        // Allow sub-elements to have clickable items that do things (like command buttons)
        return;
      }
      if (!isEvaluated) {
        onSelect(choiceId);
      }
    },
    [isEvaluated, onSelect],
  );

  return (
    <div className={styles.choicesContainer} aria-label="answer choices">
      {choices.map((choice, index) => (
        <div
          key={choice.id}
          aria-label={`choice ${index + 1}`}
          onClick={onClicked(choice.id)}
          className={classNames(styles.choicesChoiceRow, isSelected(choice.id) ? 'selected' : '')}
        >
          <div className={styles.choicesChoiceWrapper}>
            <label className={styles.choicesChoiceLabel} htmlFor={`choice-${index}`}>
              <div className="d-flex align-items-center col">
                {isSelected(choice.id) ? selectedIcon : unselectedIcon}
                <div className={classNames('content', styles.choicesChoiceContent)}>
                  <HtmlContentModelRenderer
                    content={choice.content}
                    context={context}
                    direction={choice.textDirection}
                  />
                </div>
              </div>
            </label>
          </div>
        </div>
      ))}
    </div>
  );
};
