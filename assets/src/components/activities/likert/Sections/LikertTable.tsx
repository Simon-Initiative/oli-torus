import { LikertItem, LikertModelSchema } from '../schema';
import { getChoiceValue } from '../utils';
import './LikertTable.scss';
import { Choice, ChoiceId, PartId, makeContent } from 'components/activities/types';
import { toSimpleText } from 'components/editing/slateUtils';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';

interface Props {
  model: LikertModelSchema;
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
  model,
  isSelected,
  onSelect,
  disabled = false,
  context,
}) => {
  const { choices, items, orderDescending } = model;

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
                  onChange={() => onSelect(item.id, choice.id)}
                />
              </td>
            ))}
          </tr>
        ))}
      </tbody>
      {/* footer row with choice values. Use th cells to match header style */}
      <tfoot>
        <tr>
          {needItemColumn(items) && <th />}
          {choices.map((choice, i) => (
            <th key={'foot-' + i}>
              <p>{getChoiceValue(model, i).toString()}</p>
            </th>
          ))}
        </tr>
      </tfoot>
    </table>
  );
};
