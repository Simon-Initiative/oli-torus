import * as React from 'react';
import * as Bank from 'data/content/bank';
import { LogicProps } from './common';
import { Expression } from './Expression';
import { CloseButton } from '../../components/misc/CloseButton';
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

  return (
    <div>
      <div className="d-flex justify-content-between">
        <div className="btn-group btn-group-toggle" data-toggle="buttons">
          <label
            className={`btn btn-secondary ${
              clause.operator === Bank.ClauseOperator.all ? 'active' : ''
            }`}
          >
            <input
              onChange={() => {
                onChange(Object.assign({}, clause, { operator: Bank.ClauseOperator.all }));
              }}
              disabled={!editMode}
              type="radio"
              name={id}
              checked={clause.operator === Bank.ClauseOperator.all}
            >
              All
            </input>
          </label>
          <label
            className={`btn btn-secondary ${
              clause.operator === Bank.ClauseOperator.any ? 'active' : ''
            }`}
          >
            <input
              onChange={() => {
                onChange(Object.assign({}, clause, { operator: Bank.ClauseOperator.any }));
              }}
              disabled={!editMode}
              type="radio"
              name={id}
              checked={clause.operator === Bank.ClauseOperator.any}
            >
              Or
            </input>
          </label>
        </div>
        <CloseButton editMode={props.editMode} onClick={() => props.onRemove()} />
      </div>
      {children}
    </div>
  );
};
