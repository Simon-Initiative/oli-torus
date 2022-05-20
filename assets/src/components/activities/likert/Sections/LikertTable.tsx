import React from 'react';
import { Choice, ChoiceId, PartId } from 'components/activities/types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { LikertItem } from '../schema';
import './LikertTable.scss';
import { toSimpleText } from 'components/editing/slateUtils';

interface Props {
  items: LikertItem[];
  choices: Choice[];
  isSelected: (itemId: PartId, choiceId: ChoiceId) => boolean;
  onSelect: (itemId: PartId, choiceId: ChoiceId) => void;
  disabled: boolean;
  context: WriterContext;
}

// only include item column if more than one item or single item is non-blank
const needItemColumn = (items: LikertItem[]) => {
  return items.length > 1 || toSimpleText(items[0].content).trim() != '';
};

export const LikertTable: React.FC<Props> = ({
  items,
  choices,
  isSelected,
  onSelect,
  disabled = false,
  context,
}) => {
  return (
    <table className="likertTable">
      <thead>
        <tr>
          {needItemColumn(items) && <th></th>}
          {choices.map((choice) => (
            <th key={choice.id}>
              <HtmlContentModelRenderer content={choice.content} context={context} />
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {items.map((item) => (
          <tr key={item.id}>
            {needItemColumn(items) && (
              <td>
                <HtmlContentModelRenderer content={item.content} context={context} />
              </td>
            )}
            {choices.map((choice, i) => (
              <td align="center" key={item.id + '-' + choice.id}>
                <input
                  type="radio"
                  checked={isSelected(item.id, choice.id)}
                  disabled={disabled}
                  onClick={() => onSelect(item.id, choice.id)}
                />
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
};
