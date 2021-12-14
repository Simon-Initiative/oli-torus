import { loadStripe } from '@stripe/stripe-js';
function get(selector) {
    return document.querySelector(selector);
}
// Calls stripe.confirmCardPayment
// If the card requires authentication Stripe shows a pop-up modal to
// prompt the user to enter authentication details without leaving your page.
const payWithCard = (stripe, card, clientSecret) => {
    loading(true);
    stripe
        .confirmCardPayment(clientSecret, {
        payment_method: {
            card,
        },
    })
        .then((result) => {
        if (result.error) {
            fetch('/api/v1/payments/s/failure', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ clientSecret, reason: result.error.message }),
            });
            showError(result.error.message);
        }
        else {
            orderComplete(result.paymentIntent);
        }
    });
};
/* ------- UI helpers ------- */
// Shows a success message when the payment is complete
const orderComplete = (intent) => {
    fetch('/api/v1/payments/s/success', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ intent }),
    })
        .then((result) => {
        return result.json();
    })
        .then((result) => {
        if (result.result === 'success') {
            get('.result-message a').setAttribute('href', result.url);
            get('.result-message').classList.remove('hidden');
            get('#submit').disabled = true;
        }
        else {
            showError(result.reason);
        }
    });
    loading(false);
};
// Show the customer the error from Stripe if their card fails to charge
const showError = (errorMsgText) => {
    loading(false);
    const errorMsg = get('#card-error');
    errorMsg.textContent = errorMsgText;
    setTimeout(() => {
        errorMsg.textContent = '';
    }, 4000);
};
// Show a spinner on payment submission
const loading = (isLoading) => {
    if (isLoading) {
        // Disable the button and show a spinner
        get('#submit').disabled = true;
        get('#spinner').classList.remove('hidden');
        get('#button-text').classList.add('hidden');
    }
    else {
        get('#submit').disabled = false;
        get('#spinner').classList.add('hidden');
        get('#button-text').classList.remove('hidden');
    }
};
// Ask the Torus server to create an intent with Stripe, and
// after that succeeds finalize the intent directly from the client
// to Stripe.
function doPurchase(stripe, card, purchase) {
    fetch('/api/v1/payments/s/create-payment-intent', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(purchase),
    })
        .then((result) => {
        if (!result.ok) {
            result.text().then((text) => showError(text));
        }
        else {
            return result.json();
        }
    })
        .then((data) => {
        payWithCard(stripe, card, data.clientSecret);
    });
}
// Create and init the payment form
function initPaymentForm(stripe, purchase) {
    get('#submit').disabled = true;
    const elements = stripe.elements();
    const style = {
        base: {
            color: '#32325d',
            fontFamily: 'Arial, sans-serif',
            fontSmoothing: 'antialiased',
            fontSize: '16px',
            '::placeholder': {
                color: '#32325d',
            },
        },
        invalid: {
            fontFamily: 'Arial, sans-serif',
            color: '#fa755a',
            iconColor: '#fa755a',
        },
    };
    const card = elements.create('card', { style: style });
    // Stripe injects an iframe into the DOM
    card.mount('#card-element');
    card.on('change', function (event) {
        // Disable the Pay button if there are no card details in the Element
        get('#submit').disabled = event.empty;
        get('#card-error').textContent = event.error ? event.error.message : '';
    });
    const form = document.getElementById('payment-form');
    form.addEventListener('submit', (event) => {
        event.preventDefault();
        // Complete payment when the submit button is clicked
        doPurchase(stripe, card, purchase);
    });
}
function makePurchase(key, purchase) {
    loadStripe(key).then((stripe) => {
        if (stripe !== null) {
            initPaymentForm(stripe, purchase);
        }
    });
}
window.OLIPayments = { makePurchase };
//# sourceMappingURL=client.js.map