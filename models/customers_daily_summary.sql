select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'order_date']) }} as primary_key,
    customer_id,
    order_date,
    count(*) as c
from {{ ref('stg_jaffle_shop__orders') }}
group by customer_id, order_date