var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import React from 'react';
import PartComponent from '../common/PartComponent';
const defaultHandler = () => __awaiter(void 0, void 0, void 0, function* () {
    return {
        type: 'success',
        snapshot: {},
    };
});
const PartsLayoutRenderer = ({ parts, state = {}, onPartInit = defaultHandler, onPartReady = defaultHandler, onPartSave = defaultHandler, onPartSubmit = defaultHandler, onPartResize = defaultHandler, onPartSetData, onPartGetData, }) => {
    const popups = parts.filter((part) => part.type === 'janus-popup');
    const partsWithoutPopups = parts.filter((part) => part.type !== 'janus-popup');
    const updatedParts = [...partsWithoutPopups, ...popups];
    return (<React.Fragment>
      {updatedParts.map((partDefinition) => {
            const partProps = {
                id: partDefinition.id,
                type: partDefinition.type,
                model: partDefinition.custom,
                state,
                onInit: onPartInit,
                onReady: onPartReady,
                onSave: onPartSave,
                onSubmit: onPartSubmit,
                onResize: onPartResize,
                onSetData: onPartSetData,
                onGetData: onPartGetData,
            };
            return <PartComponent key={partDefinition.id} {...partProps}/>;
        })}
    </React.Fragment>);
};
export default PartsLayoutRenderer;
//# sourceMappingURL=PartsLayoutRenderer.jsx.map