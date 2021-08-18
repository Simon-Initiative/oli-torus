import * as React from 'react';
import * as Bank from 'data/content/bank';
import { LogicProps } from './common';
import { Expression } from './Expression';
import { Clause } from './Clause';

export interface LogicBuilderProps extends LogicProps {
  logic: Bank.Logic;
  onChange: (logic: Bank.Logic) => void;
}

export const LogicBuilder: React.FC<LogicBuilderProps> = (props: LogicBuilderProps) => {
  const { logic, onChange } = props;

  const removeRoot = () => {
    const removed = Object.assign({}, logic, { conditions: null });
    onChange(removed);
  };

  const changeRoot = (conditions: any) => {
    const updated = Object.assign({}, logic, { conditions });
    onChange(updated);
  };

  let rootNode;
  if (logic.conditions === null) {
    rootNode = <span></span>;
  } else {
    rootNode =
      logic.conditions.operator === Bank.ClauseOperator.all ||
      logic.conditions.operator === Bank.ClauseOperator.any ? (
        <Clause
          {...props}
          clause={logic.conditions as Bank.Clause}
          onChange={changeRoot}
          onRemove={removeRoot}
        />
      ) : (
        <Expression
          {...props}
          expression={logic.conditions as Bank.Expression}
          onChange={changeRoot}
          onRemove={removeRoot}
        />
      );
  }

  return <div>{rootNode}</div>;
};
