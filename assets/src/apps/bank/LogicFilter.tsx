import * as React from 'react';
import * as Bank from 'data/content/bank';
import { LogicProps } from './common';
import { Expression } from './Expression';
import { Clause } from './Clause';

export interface LogicFilterProps extends LogicProps {
  expressions: Bank.Expression[];
  onChange: (expressions: Bank.Expression[]) => void;
}

const replaceAt = (array: any, index: number, item: any) => {
  const updated = array.slice();
  updated[index] = item;
  return updated;
};

export const LogicFilter: React.FC<LogicFilterProps> = (props: LogicFilterProps) => {
  const { expressions, onChange } = props;

  const changeRoot = (index: number, e: any) => {
    const updated = Object.assign({}, logic, { conditions });
    onChange(updated);
  };

  const exp = expressions.map((e: Bank.Expression, index: number) => (
    <Expression
      key={index}
      {...props}
      hideRemove={true}
      expression={e}
      onChange={changeRoot.bind(this, index)}
      onRemove={() => true}
    />
  ));

  return <div>{exp}</div>;
};
