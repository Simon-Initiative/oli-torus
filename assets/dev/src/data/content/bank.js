export var ClauseOperator;
(function (ClauseOperator) {
    ClauseOperator["all"] = "all";
    ClauseOperator["any"] = "any";
})(ClauseOperator || (ClauseOperator = {}));
export var ExpressionOperator;
(function (ExpressionOperator) {
    ExpressionOperator["contains"] = "contains";
    ExpressionOperator["doesNotContain"] = "does_not_contain";
    ExpressionOperator["equals"] = "equals";
    ExpressionOperator["doesNotEqual"] = "does_not_equal";
})(ExpressionOperator || (ExpressionOperator = {}));
export var Fact;
(function (Fact) {
    Fact["objectives"] = "objectives";
    Fact["tags"] = "tags";
    Fact["text"] = "text";
    Fact["type"] = "type";
})(Fact || (Fact = {}));
export function defaultLogic() {
    return {
        conditions: null,
    };
}
export function paging(offset, limit) {
    return {
        offset,
        limit,
    };
}
function isEmptyValue(value) {
    if (value === null) {
        return true;
    }
    else if (typeof value === 'string') {
        return value.trim() === '';
    }
    else if (value.length === 0) {
        return true;
    }
    return false;
}
// The idea here is to take a logic expression and adjust it to guarantee that it
// will not produce an error when executed on the server.  Any expression whose value
// is empty (an empty array or zero length string) will cause an error, so this impl
// seeks to find them and adjust to account for their removal.
//
// We leverage the fact that the UI is restricting logic to only contain one
// clause, so to guarantee validity we do not need a recursive solution.
//
// Here are the cases we check:
// 1. If the logic conditions are null, they are valid and we are done
// 2. If the logic conditions is a clause, then filter to leave only
//    expressions whose values are not empty
//    a. If there are no expressions left, return a logic with null conditions.
//    b. If there is only one expression, return a logic that has the outer clause removed, leaving
//       just the single expression.
//    b. Otherwise, return the logic with the clause in place with the filtered children.
// 3. If the logic conditions is just an expression and that expression value is empty,
//    return logic with null conditions.
// 4. All other cases, return the logic as-is
export function guaranteeValididty(logic) {
    if (logic.conditions === null) {
        return logic;
    }
    if (logic.conditions.operator === ClauseOperator.all ||
        logic.conditions.operator === ClauseOperator.any) {
        const children = logic.conditions.children.filter((e) => !isEmptyValue(e.value));
        if (children.length === 0) {
            return { conditions: null };
        }
        else if (children.length === 1) {
            return { conditions: children[0] };
        }
        else {
            return { conditions: Object.assign({}, logic.conditions, { children }) };
        }
    }
    else {
        if (isEmptyValue(logic.conditions.value)) {
            return { conditions: null };
        }
    }
    return logic;
}
//# sourceMappingURL=bank.js.map