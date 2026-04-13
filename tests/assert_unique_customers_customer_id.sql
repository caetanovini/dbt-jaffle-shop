select
    customer_id
from {{ ref('stg_jaffle_shop__customers') }}
group by 1
having count(*) > 1 