import { createAsyncThunk } from '@reduxjs/toolkit';
import { defaultGlobalEnv, evalScript } from 'adaptivity/scripting';
import { DeliveryRootState } from 'apps/delivery/store/rootReducer';
import { selectActiveEverapp, setActiveEverapp } from '../slice';
import PageSlice from '../name';

export const toggleEverapp = createAsyncThunk(
  `${PageSlice}/toggleEverapp`,
  async (payload: { id: string }, thunkAPI) => {
    const { dispatch, getState } = thunkAPI;
    const currentActiveApp = selectActiveEverapp(getState() as DeliveryRootState);

    // need to sync up id with scripting environment
    const { id } = payload;

    let activeAppId = currentActiveApp;
    if (currentActiveApp !== id) {
      activeAppId = id;
    } else {
      activeAppId = '';
    }
    // trap states are looking for "none"
    evalScript(`let app.active = "${activeAppId || 'none'}";`, defaultGlobalEnv);

    dispatch(setActiveEverapp({ id: activeAppId }));
  },
);
