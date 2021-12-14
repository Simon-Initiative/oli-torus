import { Responses } from 'data/activities/model/responses';
import { getPartById } from 'data/activities/model/utils';
export const ShortAnswerActions = {
    setInputType(inputType, partId) {
        return (model) => {
            if (model.inputType === inputType)
                return;
            if (inputType === 'text' || inputType === 'textarea') {
                getPartById(model, partId).responses = Responses.forTextInput();
            }
            else if (inputType === 'numeric') {
                getPartById(model, partId).responses = Responses.forNumericInput();
            }
            model.inputType = inputType;
        };
    },
};
//# sourceMappingURL=actions.js.map