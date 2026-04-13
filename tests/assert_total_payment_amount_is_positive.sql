--select
--    order_id, 
--    sum(amount) as sum_amount
--from {{ ref('fct_orders') }}
--group by 1
--having sum(amount) < 0 

select
    order_id,
    sum(amount) as total_amount
from {{ ref('fct_orders' )}}
group by 1
having not(sum(amount) >= 0)