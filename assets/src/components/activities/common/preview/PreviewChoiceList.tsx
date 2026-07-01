import React from 'react';
import { Choice, ChoiceId } from 'components/activities/types';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { Radio } from 'components/misc/icons/radio/Radio';
import { PreviewRichText } from './PreviewRichText';

interface Props {
  choices: Choice[];
  selectedChoiceIds: ChoiceId[];
  multiSelect?: boolean;
  showSelectionControl?: boolean;
  surface?: 'card' | 'plain';
}

export const PreviewChoiceList: React.FC<Props> = ({
  choices,
  selectedChoiceIds,
  multiSelect = false,
  showSelectionControl = true,
  surface = 'card',
}) => {
  const selectedIds = new Set(selectedChoiceIds);
  const UncheckedIcon = multiSelect ? Checkbox.Unchecked : Radio.Unchecked;
  const CheckedIcon = multiSelect ? Checkbox.Checked : Radio.Checked;
  const itemClassName =
    surface === 'plain'
      ? `min-w-0 ${showSelectionControl ? 'flex items-start gap-3 py-1' : 'py-1'}`
      : `rounded-md border border-Border-border-default bg-Surface-surface-secondary-muted p-3 ${
          showSelectionControl ? 'flex items-start gap-3' : ''
        }`;

  return (
    <div className="flex flex-col gap-2">
      {choices.map((choice) => {
        const isSelected = selectedIds.has(choice.id);

        return (
          <div key={choice.id} className={itemClassName}>
            {showSelectionControl && (
              <div className="mt-0.5 shrink-0 text-primary">
                {isSelected ? <CheckedIcon disabled /> : <UncheckedIcon disabled />}
              </div>
            )}
            <PreviewRichText
              content={choice.content}
              className="min-w-0 flex-1 text-base leading-7 text-Text-text-high [&_.content_p]:my-0"
              direction={choice.textDirection || 'auto'}
            />
          </div>
        );
      })}
    </div>
  );
};
