var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import { authoringObservedAttributes, customEvents as apiCustomEvents, observedAttributes as apiObservedAttributes, } from '../partsApi';
import PopupAuthor from './PopupAuthor';
import { adaptivitySchema, createSchema, getCapabilities, schema, transformModelToSchema, transformSchemaToModel, uiSchema, } from './schema';
const observedAttributes = [...apiObservedAttributes, ...authoringObservedAttributes];
const customEvents = Object.assign(Object.assign({}, apiCustomEvents), { onConfigure: 'configure', onSaveConfigure: 'saveconfigure', onCancelConfigure: 'cancelconfigure' });
register(PopupAuthor, manifest.authoring.element, observedAttributes, {
    customEvents,
    shadow: false,
    attrs: {
        model: {
            json: true,
        },
    },
    customApi: {
        getSchema: () => schema,
        getUiSchema: () => uiSchema,
        getAdaptivitySchema: () => __awaiter(void 0, void 0, void 0, function* () { return adaptivitySchema; }),
        transformModelToSchema,
        transformSchemaToModel,
        createSchema,
        getCapabilities,
    },
});
//# sourceMappingURL=authoring-entry.js.map