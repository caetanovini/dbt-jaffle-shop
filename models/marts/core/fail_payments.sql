{{ config(
    materialized = 'ephemeral'
)}}

select 
    payment_method
    ,status
    ,SUM(amount) amount
from {{ ref('stg_stripe__payments') }}
where status = 'fail'
group by 1,2