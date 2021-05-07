// For a modal already present in the DOM, show it from the element id
export const showModal = (elementId: string) => {
  const modal = document.getElementById(elementId) as any;
  (window as any).$(modal).modal('show');
}
