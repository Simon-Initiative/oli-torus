
export module modalActions {

  export type DISPLAY_MODAL = 'DISPLAY_MODAL';
  export const DISPLAY_MODAL : DISPLAY_MODAL = 'DISPLAY_MODAL';

  export type DISMISS_MODAL = 'DISMISS_MODAL';
  export const DISMISS_MODAL : DISMISS_MODAL = 'DISMISS_MODAL';

  export type displayAction = {
    type: DISPLAY_MODAL,
    component: any,
  };

  export type dismissAction = { type: DISMISS_MODAL };

  export function display(component: any) : displayAction {
    return {
      type: DISPLAY_MODAL,
      component,
    };
  }

  export function dismiss() : dismissAction {
    return { type: DISMISS_MODAL };
  }

}
