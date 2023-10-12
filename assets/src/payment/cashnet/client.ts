export {};

// Get element from DOM
function get(selector: string): any {
  return document.querySelector(selector) as any;
}

function isIniFrame(): boolean {
  return window.location !== window.parent.location;
}

function configFormForIframe() {
  get('#sub').classList.remove('hidden');
  get('#spinner').classList.add('hidden');
  get('#cmupayment').target = '_blank';
  get('#signouturlfield').value =
    window.location.origin + '/api/v1/payments/c/signoff?ref1val1=' + get('#ref1val1field').value;
}

function makeCashnetPurchase(_purchase: any) {
  const f = document.forms.namedItem('cashnet');
  if (f) {
    if (isIniFrame()) {
      configFormForIframe();
      f.addEventListener('submit', (event: any) => {
        get('#sub').classList.add('hidden');
        get('#spinner').classList.remove('hidden');
      });
    } else {
      f.submit();
      f.remove();
    }
  }
}
declare global {
  interface Window {
    OLICashnetPayments: { makeCashnetPurchase: typeof makeCashnetPurchase };
  }
}

window.OLICashnetPayments = { makeCashnetPurchase };
