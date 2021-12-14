import guid from 'utils/guid';
import { create } from '../../data/content/model/elements/factories';
export function makeUndoable(description, operations) {
    return {
        type: 'Undoable',
        description,
        operations,
    };
}
export function makeContent(text, id) {
    return {
        id: id ? id : guid(),
        content: [
            create({
                type: 'p',
                children: [{ text }],
                id: guid(),
            }),
        ],
    };
}
export const makeChoice = makeContent;
export const makeStem = makeContent;
export const makeHint = makeContent;
export const makeFeedback = makeContent;
export const makeTransformation = (path, operation) => ({
    id: guid(),
    path,
    operation,
});
export const makeResponse = (rule, score, text = '') => ({
    id: guid(),
    rule,
    score,
    feedback: makeFeedback(text),
});
export const makePart = (responses, 
// By default, parts have 3 hints (deer in headlights, cognitive, bottom out)
// Multiinput activity parts start with just one hint
hints = [makeHint(''), makeHint(''), makeHint('')], id) => ({
    id: id ? id : guid(),
    scoringStrategy: ScoringStrategy.average,
    responses,
    hints,
});
export var ScoringStrategy;
(function (ScoringStrategy) {
    ScoringStrategy["average"] = "average";
    ScoringStrategy["best"] = "best";
    ScoringStrategy["most_recent"] = "most_recent";
})(ScoringStrategy || (ScoringStrategy = {}));
export var EvaluationStrategy;
(function (EvaluationStrategy) {
    EvaluationStrategy["regex"] = "regex";
    EvaluationStrategy["numeric"] = "numeric";
    EvaluationStrategy["none"] = "none";
})(EvaluationStrategy || (EvaluationStrategy = {}));
export var Transform;
(function (Transform) {
    Transform["shuffle"] = "shuffle";
})(Transform || (Transform = {}));
export const makePreviewText = () => '';
//# sourceMappingURL=types.js.map