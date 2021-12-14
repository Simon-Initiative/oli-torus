// eslint-disable-next-line
export var modalActions;
(function (modalActions) {
    modalActions.DISPLAY_MODAL = 'DISPLAY_MODAL';
    modalActions.DISMISS_MODAL = 'DISMISS_MODAL';
    function display(component) {
        return {
            type: modalActions.DISPLAY_MODAL,
            component,
        };
    }
    modalActions.display = display;
    function dismiss() {
        return { type: modalActions.DISMISS_MODAL };
    }
    modalActions.dismiss = dismiss;
})(modalActions || (modalActions = {}));
//# sourceMappingURL=modal.js.map