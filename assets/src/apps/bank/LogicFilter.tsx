import * as React from 'react';
import * as Bank from 'data/content/bank';
import { Expression } from '../../components/logic/Expression';
import { LogicProps } from '../../components/logic/common';

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
    const expressions = replaceAt(props.expressions, index, e);
    onChange(expressions);
  };

  const exp = expressions.map((e: Bank.Expression, index: number) => (
    <Expression
      key={index}
      {...props}
      fixedFact={true}
      expression={e}
      onChange={changeRoot.bind(this, index)}
      onRemove={() => true}
    />
  ));

  return <div className="logic">{exp}</div>;
};
