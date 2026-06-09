import React from 'react';
import { ChoiceId, PartId } from 'components/activities/types';
import { toSimpleText } from 'components/editing/slateUtils';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { classNames } from 'utils/classNames';
import { LikertItem, LikertModelSchema } from '../schema';
import { getChoiceValue } from '../utils';

interface Props {
  model: LikertModelSchema;
  isSelected: (itemId: PartId, choiceId: ChoiceId) => boolean;
  onSelect: (itemId: PartId, choiceId: ChoiceId) => void;
  disabled: boolean;
  context: WriterContext;
  interactive?: boolean;
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
  interactive = true,
}) => {
  const { choices, items } = model;
  const showItemColumn = needItemColumn(items);

  return (
    <div className="w-full overflow-x-auto">
      <table className="min-w-full w-full table-fixed border-collapse text-sm text-Text-text-high">
        <thead>
          <tr>
            {showItemColumn && (
              <th className="w-[36%] border border-Border-border-default bg-Surface-surface-primary px-5 py-4 text-left align-middle font-medium" />
            )}
            {choices.map((choice) => (
              <th
                key={choice.id}
                className="border border-Border-border-default bg-Surface-surface-primary px-4 py-4 text-center align-middle text-[15px] font-semibold leading-6 text-Text-text-medium"
              >
                <div className="[&_.content_p]:my-0">
                  <HtmlContentModelRenderer
                    direction={choice.textDirection}
                    content={choice.content}
                    context={context}
                  />
                </div>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.id}>
              {showItemColumn && (
                <td className="border border-Border-border-default bg-Surface-surface-secondary-muted px-5 py-4 align-top text-base text-Text-text-high">
                  <div className="leading-7 [&_.content_p]:my-0">
                    <HtmlContentModelRenderer
                      direction={item.textDirection}
                      content={item.content}
                      context={context}
                    />
                  </div>
                </td>
              )}
              {choices.map((choice) => (
                <td
                  key={item.id + '-' + choice.id}
                  className="h-20 border border-Border-border-default bg-Surface-surface-secondary-muted px-4 py-4 text-center align-middle"
                >
                  <input
                    type="radio"
                    className={classNames('oli-radio', !interactive && 'pointer-events-none')}
                    checked={isSelected(item.id, choice.id)}
                    disabled={disabled}
                    readOnly={!interactive}
                    tabIndex={interactive ? 0 : -1}
                    onChange={() => {
                      if (interactive) {
                        onSelect(item.id, choice.id);
                      }
                    }}
                  />
                </td>
              ))}
            </tr>
          ))}
        </tbody>
        {/* footer row with choice values. Use th cells to match header style */}
        <tfoot>
          <tr>
            {showItemColumn && (
              <th className="border border-Border-border-default bg-Surface-surface-secondary-muted px-5 py-3 text-left align-middle font-normal" />
            )}
            {choices.map((choice, i) => (
              <th
                key={'foot-' + i}
                className="border border-Border-border-default bg-Surface-surface-secondary-muted px-4 py-3 text-center align-middle text-sm font-normal text-Text-text-low"
              >
                <p className="m-0">{getChoiceValue(model, i).toString()}</p>
              </th>
            ))}
          </tr>
        </tfoot>
      </table>
    </div>
  );
};
