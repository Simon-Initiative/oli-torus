import { makeRule, parseInputFromRule, parseOperatorFromRule, } from 'data/activities/model/rules';
import { useState } from 'react';
import React from 'react';
import { NumericInput } from 'components/activities/short_answer/sections/NumericInput';
import { TextInput } from 'components/activities/short_answer/sections/TextInput';
export const InputEntry = ({ inputType, response, onEditResponseRule }) => {
    const [{ operator, input }, setState] = useState({
        input: parseInputFromRule(response.rule),
        operator: parseOperatorFromRule(response.rule),
    });
    const onEditRule = (inputState) => {
        setState(inputState);
        onEditResponseRule(response.id, makeRule(inputState.operator, inputState.input));
    };
    const shared = {
        state: { operator, input },
        setState: onEditRule,
    };
    if (inputType === 'numeric') {
        return <NumericInput {...shared}/>;
    }
    return <TextInput {...shared}/>;
};
//# sourceMappingURL=InputEntry.jsx.map