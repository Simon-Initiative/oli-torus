export {};

function makeCashnetPurchase(_purchase: any) {
  const f = document.forms.namedItem('cashnet');
  if (f) {
    f.submit();
    f.remove();
  }
}
declare global {
  interface Window {
    OLICashnetPayments: { makeCashnetPurchase: typeof makeCashnetPurchase };
  }
}

window.OLICashnetPayments = { makeCashnetPurchase };
