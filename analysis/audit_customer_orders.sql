{#
=============================================================================
AUDIT SCRATCHPAD: customer_orders vs fct_customer_orders
=============================================================================
Purpose: Validate that the refactored 'fct_customer_orders' model produces
identical results to the legacy 'customer_orders' model.

This file uses the dbt audit_helper package to compare both models
row by row and column by column.

Prerequisites:
  1. Add audit_helper to packages.yml:
       - package: dbt-labs/audit_helper
         version: 0.13.0
  2. Run: dbt deps
  3. Make sure both models exist in your database
  4. Compile: dbt compile --select audit_customer_orders
  5. Run the compiled SQL in psql or the PostgreSQL VSCode extension
=============================================================================
#}


{#
-----------------------------------------------------------------------------
AUDIT 1: compare_relations (ACTIVE)
Compares the two models row by row using order_id as the primary key.
Returns a summary showing how many rows are:
  - identical in both models
  - only in model A (customer_orders)
  - only in model B (fct_customer_orders)
  - modified (same primary key but different values)
-----------------------------------------------------------------------------
#}

{% set old_etl_relation = ref('stg_jaffle_shop__customers') %}
{% set dbt_relation = ref('fct_customer_orders') %}

{{ audit_helper.compare_relations(
    a_relation = old_etl_relation,
    b_relation = dbt_relation,
    primary_key = 'order_id'
) }}


{#
=============================================================================
AUDIT 2: compare_relation_columns
Compares column names and data types between the two models.
Useful to catch column renames or type changes during refactoring.

To activate: comment out Audit 1 above and uncomment the block below
by removing the inner comment markers.

-- Uncomment to use:
-- set old_etl_relation = ref('customer_orders')
-- set dbt_relation = ref('fct_customer_orders')
-- audit_helper.compare_relation_columns(
--     a_relation = old_etl_relation,
--     b_relation = dbt_relation
-- )
=============================================================================
#}


{#
=============================================================================
AUDIT 3: compare_column_values
Compares a single column's values between both models.
Useful when Audit 1 shows differences and you want to pinpoint
which specific column is causing the mismatch.

To activate: comment out Audit 1 above and uncomment the block below
by removing the inner comment markers.

-- Uncomment to use:
-- set old_etl_relation = ref('customer_orders')
-- set dbt_relation = ref('fct_customer_orders')
-- audit_helper.compare_column_values(
--     a_relation = old_etl_relation,
--     b_relation = dbt_relation,
--     primary_key = 'order_id',
--     column_to_compare = 'total_amount_paid'
-- )
=============================================================================
#}


{#
=============================================================================
HOW TO INTERPRET RESULTS FROM compare_relations:

in_a_only  - rows in customer_orders but NOT in fct_customer_orders
in_b_only  - rows in fct_customer_orders but NOT in customer_orders
in_both    - rows sharing the same primary key in both models
identical  - rows completely identical across all columns
modified   - rows with same primary key but different column values

A perfect audit result shows:
  in_a_only = 0
  in_b_only = 0
  modified  = 0
  identical = 100% of rows
=============================================================================
#}