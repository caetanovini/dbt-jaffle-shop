select
    id as order_id,
    user_id as customer_id,
    order_date,
    case 
        when status not in ('returned','return_pending') 
        then order_date 
    end as valid_order_date,
    case
        when status like '%shipped%' then 'shipped'
        when status like '%return%' then 'returned'
        when status like '%pending%' then 'placed'
        else status 
    end as status
from {{ source('jaffle_shop', 'orders') }}