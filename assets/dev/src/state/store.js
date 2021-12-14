import { createStore, applyMiddleware } from 'redux';
import { composeWithDevTools } from 'redux-devtools-extension';
import { createLogger } from 'redux-logger';
import thunk from 'redux-thunk';
import rootReducer, { initState } from 'state';
import nextReducer from './index';
export function configureStore(initialState, reducer) {
    const logger = createLogger({
        stateTransformer: (state) => {
            const newState = {};
            // automatically converts any immutablejs objects to JS representation
            for (const i of Object.keys(state)) {
                if (state[i].toJS) {
                    newState[i] = state[i].toJS();
                }
                else {
                    newState[i] = state[i];
                }
            }
            return newState;
        },
    });
    let middleware;
    if (process.env.NODE_ENV === 'development') {
        middleware = composeWithDevTools(applyMiddleware(thunk, logger));
    }
    else {
        middleware = composeWithDevTools(applyMiddleware(thunk));
    }
    // For backwards compatibility - only use initial state without calling
    // `initState` if a reducer is passed
    const store = createStore(reducer ? reducer : rootReducer, reducer && initialState ? initialState : initState(initialState), middleware);
    if (module.hot) {
        module.hot.accept('./index', () => {
            store.replaceReducer(reducer ? reducer : nextReducer);
        });
    }
    return store;
}
//# sourceMappingURL=store.js.map