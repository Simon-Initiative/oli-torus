// For a modal already present in the DOM, show it from the element id
export const showModal = (elementId) => {
    const modal = document.getElementById(elementId);
    window.$(modal).modal('show');
};
//# sourceMappingURL=modal.js.map