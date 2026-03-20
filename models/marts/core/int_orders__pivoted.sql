{%- set payment_methods = ['coupon', 'credit_card', 'bank_transfer', 'gift_card'] -%}

with payments as (
    select *
    from {{ ref('stg_stripe__payments') }}
    where status = 'success'
)
select 
    order_id,
    {% for payment_method in payment_methods %}
        sum(case when payment_method = '{{ payment_method }}' then amount else 0 end) as {{ payment_method }}_total_amount
        {%- if not loop.last -%}
            ,
        {%- endif -%}
    {% endfor %}
from payments
group by order_id