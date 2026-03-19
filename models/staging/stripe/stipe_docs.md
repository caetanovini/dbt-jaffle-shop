{% docs payment_method %}

The payment method used by the customer to complete the transaction.

Possible values are:
- `credit_card` — Payment made using a credit card.
- `coupon` — Payment made using a discount coupon code.
- `bank_transfer` — Payment made via direct bank transfer.
- `gift_card` — Payment made using a gift card balance.

{% enddocs %}


{% docs payment_status %}

The final status of the payment attempt made by the customer.

Possible values are:
- `success` — The payment was completed and funds were captured successfully.
- `fail` — The payment attempt was rejected or failed to process.
- `pending` — The payment is awaiting confirmation or processing.

{% enddocs %}