import React, { useCallback, useRef, useState } from 'react';
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
  disabled?: boolean;
  multiSelect?: boolean;
}
export const ChoicesDelivery: React.FC<Props> = ({
  choices,
  selected,
  context,
  onSelect,
  isEvaluated,
  unselectedIcon,
  selectedIcon,
  disabled = false,
  multiSelect = false,
}) => {
  const choiceRefs = useRef<(HTMLDivElement | null)[]>([]);
  const isSelected = (choiceId: ChoiceId) => !!selected.find((s) => s === choiceId);

  // Track which choice is currently focusable (roving tabindex)
  // Initialize to selected index, or 0 if nothing selected
  const getInitialFocusIndex = () => {
    if (selected.length > 0) {
      const selectedIndex = choices.findIndex((c) => selected.includes(c.id));
      return selectedIndex >= 0 ? selectedIndex : 0;
    }
    return 0;
  };
  const [focusedIndex, setFocusedIndex] = useState(getInitialFocusIndex);

  const onClicked = useCallback(
    (choiceId: ChoiceId, index: number) => (event: React.MouseEvent) => {
      if (event.isDefaultPrevented()) {
        // Allow sub-elements to have clickable items that do things (like command buttons)
        return;
      }
      if (!isEvaluated && !disabled) {
        setFocusedIndex(index);
        onSelect(choiceId);
      }
    },
    [isEvaluated, disabled, onSelect],
  );

  const onKeyDown = useCallback(
    (choiceId: ChoiceId, index: number) => (event: React.KeyboardEvent) => {
      const { key } = event;

      // Handle arrow key navigation (move focus without selecting)
      if (key === 'ArrowDown' || key === 'ArrowRight') {
        event.preventDefault();
        const nextIndex = (index + 1) % choices.length;
        setFocusedIndex(nextIndex);
        choiceRefs.current[nextIndex]?.focus();
        return;
      }

      if (key === 'ArrowUp' || key === 'ArrowLeft') {
        event.preventDefault();
        const prevIndex = (index - 1 + choices.length) % choices.length;
        setFocusedIndex(prevIndex);
        choiceRefs.current[prevIndex]?.focus();
        return;
      }

      // Handle selection with Space or Enter
      if (key === ' ' || key === 'Enter') {
        event.preventDefault();
        if (!isEvaluated && !disabled) {
          onSelect(choiceId);
        }
      }
    },
    [choices.length, isEvaluated, disabled, onSelect],
  );

  // For checkbox groups, all items can be in tab order
  // For radio groups, only one item should be in tab order (roving tabindex)
  const getTabIndex = (index: number): number => {
    if (disabled) return -1;
    if (multiSelect) return 0; // All checkboxes are tabbable
    return index === focusedIndex ? 0 : -1; // Only focused radio is tabbable
  };

  // ARIA roles depend on whether this is single or multi-select
  const containerRole = multiSelect ? 'group' : 'radiogroup';
  const itemRole = multiSelect ? 'checkbox' : 'radio';

  return (
    <div
      className={styles.choicesContainer}
      role={containerRole}
      aria-label="answer choices"
    >
      {choices.map((choice, index) => (
        <div
          key={choice.id}
          ref={(el) => (choiceRefs.current[index] = el)}
          role={itemRole}
          aria-checked={isSelected(choice.id)}
          aria-label={`choice ${index + 1}`}
          tabIndex={getTabIndex(index)}
          onClick={disabled ? undefined : onClicked(choice.id, index)}
          onKeyDown={disabled ? undefined : onKeyDown(choice.id, index)}
          className={classNames(
            styles.choicesChoiceRow,
            isSelected(choice.id) ? 'selected' : '',
            disabled ? 'disabled' : '',
          )}
          style={{ cursor: disabled ? 'default' : 'pointer' }}
        >
          <div className={styles.choicesChoiceWrapper} dir={choice.textDirection}>
            <div className={styles.choicesChoiceLabel}>
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
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};
