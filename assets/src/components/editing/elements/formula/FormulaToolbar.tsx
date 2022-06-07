import React, { Dispatch, SetStateAction } from 'react';
import { FormulaSubTypes } from '../../../../data/content/model/elements/types';

const markups: Array<{ label: string; code: FormulaSubTypes; reference?: string }> = [
  {
    label: 'Latex',
    code: 'latex',
    reference: 'https://en.wikibooks.org/wiki/LaTeX/Mathematics',
  },
  {
    label: 'MathML',
    code: 'mathml',
    reference: 'https://developer.mozilla.org/en-US/docs/Web/MathML/Element',
  },
];

const getToolbarClass = (buttonType: string, activeType: string) =>
  buttonType === activeType ? 'language-active' : 'language';

interface Props {
  setSubtype: Dispatch<SetStateAction<FormulaSubTypes>>;
  subtype: string;
}

export const FormulaToolbar: React.FC<Props> = ({ setSubtype, subtype }) => {
  const onClickSubtype = React.useCallback(
    (newSubType: FormulaSubTypes) => (_event: any) => {
      setSubtype(newSubType);
    },
    [subtype],
  );

  const active = markups.find((m) => m.code === subtype);

  return (
    <div className="toolbar">
      <div className="buttons">
        {markups.map((m) => (
          <button
            key={m.code}
            onClick={onClickSubtype(m.code)}
            className={getToolbarClass(m.code, subtype)}
          >
            {m.label}
          </button>
        ))}
      </div>

      {active?.reference && (
        <a target="_blank" rel="noreferrer" href={active.reference}>
          {active.label} Reference
        </a>
      )}
    </div>
  );
};
