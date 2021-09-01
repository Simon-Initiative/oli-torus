import * as React from 'react';
import * as Bank from 'data/content/bank';
import { LogicProps } from './common';
import { Expression } from './Expression';
import { CloseButton } from '../misc/CloseButton';
import guid from 'utils/guid';

export interface ClauseProps extends LogicProps {
  clause: Bank.Clause;
  onChange: (clause: Bank.Clause) => void;
}

const replaceAt = (array: any, index: number, item: any) => {
  const updated = array.slice();
  updated[index] = item;
  return updated;
};

const removeAt = (array: any, index: number) => {
  const updated = array.slice();
  updated.splice(index, 1);
  return updated;
};

export const Clause: React.FC<ClauseProps> = (props: ClauseProps) => {
  const [id] = React.useState(guid());
  const { clause, editMode, onChange } = props;

  const children = (clause.children as any).map((c: any, i: number) => {
    if (c.operator === Bank.ClauseOperator.all || c.operator === Bank.ClauseOperator.any) {
      return (
        <Clause
          {...props}
          clause={c}
          onChange={(e) => {
            const index = i;
            onChange(Object.assign({}, clause, { children: replaceAt(clause.children, index, e) }));
          }}
          onRemove={() => {
            const index = i;
            onChange(Object.assign({}, clause, { children: removeAt(clause.children, index) }));
          }}
        />
      );
    } else {
      return (
        <Expression
          {...props}
          expression={c as unknown as Bank.Expression}
          onChange={(e) => {
            const index = i;
            onChange(Object.assign({}, clause, { children: replaceAt(clause.children, index, e) }));
          }}
          onRemove={() => {
            const index = i;
            onChange(Object.assign({}, clause, { children: removeAt(clause.children, index) }));
          }}
        />
      );
    }
  });

  const onOperatorChange = (e: any) => {
    onChange(Object.assign({}, clause, { operator: e.currentTarget.value }));
  };

  return (
    <div>
      <div className="d-flex justify-content-between mb-3">
        <div>
          <div className="form-check form-check-inline">
            <input
              disabled={!editMode}
              onChange={onOperatorChange}
              className="form-check-input"
              type="radio"
              name={'clause_radio_' + id}
              id={'radio1_' + id}
              value={Bank.ClauseOperator.all}
              checked={clause.operator === Bank.ClauseOperator.all}
            />
            <label className="form-check-label" htmlFor={'radio1_' + id}>
              All of the following
            </label>
          </div>
          <div className="form-check form-check-inline">
            <input
              disabled={!editMode}
              onChange={onOperatorChange}
              className="form-check-input"
              type="radio"
              name={'clause_radio_' + id}
              id={'radio2_' + id}
              value={Bank.ClauseOperator.any}
              checked={clause.operator === Bank.ClauseOperator.any}
            />
            <label className="form-check-label" htmlFor={'radio2_' + id}>
              Any of the following
            </label>
          </div>
        </div>
        <CloseButton editMode={props.editMode} onClick={() => props.onRemove()} />
      </div>
      {children}
    </div>
  );
};
