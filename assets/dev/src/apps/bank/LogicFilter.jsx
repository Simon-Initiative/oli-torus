import * as React from 'react';
import { Expression } from '../../components/logic/Expression';
const replaceAt = (array, index, item) => {
    const updated = array.slice();
    updated[index] = item;
    return updated;
};
export const LogicFilter = (props) => {
    const { expressions, onChange } = props;
    const changeRoot = (index, e) => {
        const expressions = replaceAt(props.expressions, index, e);
        onChange(expressions);
    };
    const exp = expressions.map((e, index) => (<Expression key={index} {...props} fixedFact={true} expression={e} onChange={changeRoot.bind(this, index)} onRemove={() => true}/>));
    return <div className="logic">{exp}</div>;
};
//# sourceMappingURL=LogicFilter.jsx.map