var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { createAsyncThunk } from '@reduxjs/toolkit';
import { defaultGlobalEnv, evalScript } from 'adaptivity/scripting';
import { PageSlice, selectActiveEverapp, setActiveEverapp } from '../slice';
export const toggleEverapp = createAsyncThunk(`${PageSlice}/toggleEverapp`, (payload, thunkAPI) => __awaiter(void 0, void 0, void 0, function* () {
    const { dispatch, getState } = thunkAPI;
    const currentActiveApp = selectActiveEverapp(getState());
    // need to sync up id with scripting environment
    const { id } = payload;
    let activeAppId = currentActiveApp;
    if (currentActiveApp !== id) {
        activeAppId = id;
    }
    else {
        activeAppId = '';
    }
    // trap states are looking for "none"
    evalScript(`let app.active = "${activeAppId || 'none'}";`, defaultGlobalEnv);
    dispatch(setActiveEverapp({ id: activeAppId }));
}));
//# sourceMappingURL=toggleEverapp.js.map