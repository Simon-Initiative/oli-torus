import * as React from 'react';
import * as Bank from 'data/content/bank';
import { Expression } from './Expression';
import { Clause } from './Clause';
export const LogicBuilder = (props) => {
    const { logic, onChange } = props;
    const removeRoot = () => {
        const removed = Object.assign({}, logic, { conditions: null });
        onChange(removed);
    };
    const changeRoot = (conditions) => {
        const updated = Object.assign({}, logic, { conditions });
        onChange(updated);
    };
    let rootNode;
    if (logic.conditions === null) {
        rootNode = <span></span>;
    }
    else {
        rootNode =
            logic.conditions.operator === Bank.ClauseOperator.all ||
                logic.conditions.operator === Bank.ClauseOperator.any ? (<Clause {...props} clause={logic.conditions} onChange={changeRoot} onRemove={removeRoot}/>) : (<Expression {...props} expression={logic.conditions} onChange={changeRoot} onRemove={removeRoot}/>);
    }
    return <div className="logic">{rootNode}</div>;
};
//# sourceMappingURL=LogicBuilder.jsx.map