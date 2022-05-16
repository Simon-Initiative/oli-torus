import React from 'react';
import { Choice, ChoiceId, PartId } from 'components/activities/types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import './LikertTable.scss';

interface Props {
  items: Choice[];
  choices: Choice[];
  isSelected: (itemId: PartId, choiceId: ChoiceId) => boolean;
  onSelect: (itemId: PartId, choiceId: ChoiceId) => void;
  disabled: boolean;
  context: WriterContext;
}
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
          <th></th>
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
            <td>
              <HtmlContentModelRenderer content={item.content} context={context} />
            </td>
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
