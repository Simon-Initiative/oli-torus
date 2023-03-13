export {};

// Get element from DOM
function get(selector: string): any {
  return document.querySelector(selector) as any;
}

// Show the customer the error from Stripe if their card fails to charge
const showError = (errorMsgText: any) => {
  loading(false);
  const errorMsg = get('#card-error');
  errorMsg.textContent = errorMsgText;
  setTimeout(() => {
    errorMsg.textContent = '';
  }, 4000);
};

// Show a spinner on payment submission
const loading = (isLoading: boolean) => {
  if (isLoading) {
    // Disable the button and show a spinner
    get('#submit').disabled = true;
    get('#spinner').classList.remove('hidden');
    get('#button-text').classList.add('hidden');
  } else {
    get('#submit').disabled = false;
    get('#spinner').classList.add('hidden');
    get('#button-text').classList.remove('hidden');
  }
};

// Ask the Torus server to create a cashnet payment form
// after that succeeds launch the form into cashnet payment portal
function doPurchase(purchase: any) {
  loading(true);
  fetch('/api/v1/payments/c/create-payment-form', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(purchase),
  })
    .then((result) => {
      if (!result.ok) {
        result.text().then((text) => showError(text));
      } else {
        return result.json();
      }
    })
    .then((data) => {
      const d = document.getElementById('cashnet-form');
      d?.insertAdjacentHTML('afterbegin', data.cashnetForm);
      const f = document.forms.namedItem('cashnet');
      if (f) {
        f.submit();
        f.remove();
      }

      loading(false);
      get('#submit').disabled = true;
    });
}

function makeCashnetPurchase(purchase: any) {
  const form = document.getElementById('payment-form') as any;
  form.addEventListener('submit', (event: any) => {
    event.preventDefault();
    // Complete payment when the submit button is clicked
    doPurchase(purchase);
  });
}

declare global {
  interface Window {
    OLICashnetPayments: { makeCashnetPurchase: typeof makeCashnetPurchase };
  }
}

window.OLICashnetPayments = { makeCashnetPurchase };
