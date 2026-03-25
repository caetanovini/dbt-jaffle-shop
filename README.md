# 🏪 Jaffle Shop — dbt Fundamentals Project

> This project was built as part of the **[dbt Fundamentals (VSCode)](https://learn.getdbt.com/)**, **[Jinja, Macros, and Packages](https://learn.getdbt.com/)**, **[Materialization Fundamentals](https://learn.getdbt.com/)**, and **[Incremental Models](https://learn.getdbt.com/)** courses, available on the official dbt Learning platform. It demonstrates core analytics engineering concepts using **dbt-core** with a **PostgreSQL** database running on **Docker**, adapted from the original Snowflake-based course.

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Data Architecture](#-data-architecture)
- [Project Structure](#-project-structure)
- [Local Setup](#-local-setup)
- [dbt Commands Reference](#-dbt-commands-reference)
- [Key dbt Concepts](#-key-dbt-concepts)
- [Data Layers Explained](#-data-layers-explained)
- [Jinja, Macros & Packages](#-jinja-macros--packages)
- [Materialization Fundamentals](#-materialization-fundamentals)
- [Incremental Models](#-incremental-models)
- [CI/CD with dbt](#-cicd-with-dbt)
- [Environments — Dev & Prod](#-environments--dev--prod)
- [ref() and source() Functions](#-ref-and-source-functions)
- [Snowflake vs PostgreSQL Differences](#-snowflake-vs-postgresql-differences)
- [Resources](#-resources)

---

## 🔎 Project Overview

The **Jaffle Shop** is a fictional food delivery business. This project transforms raw transactional data from two source systems — an internal ordering system and Stripe payments — into clean, analytics-ready models.

**Tech Stack:**
- **dbt-core** `1.11.7` — transformation framework
- **dbt-postgres** `1.10.0` — PostgreSQL adapter
- **PostgreSQL 15** — data warehouse (via Docker)
- **Python 3.12** — required runtime for dbt-core
- **Docker Desktop** — containerised PostgreSQL environment

**Data Sources:**
- `jaffle_shop` — internal ordering system (customers & orders)
- `stripe` — payment processing platform

---

## 🏗️ Data Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     RAW SOURCES                         │
│                                                         │
│   jaffle_shop.customers    jaffle_shop.orders           │
│   stripe.payment                                        │
└────────────────────┬────────────────────────────────────┘
                     │  {{ source() }}
                     ▼
┌─────────────────────────────────────────────────────────┐
│                   STAGING LAYER                         │
│                                                         │
│   stg_jaffle_shop__customers                            │
│   stg_jaffle_shop__orders                               │
│   stg_stripe__payments                                  │
└────────────────────┬────────────────────────────────────┘
                     │  {{ ref() }}
                     ▼
┌─────────────────────────────────────────────────────────┐
│                    MARTS LAYER                          │
│                                                         │
│   finance/  fct_orders        (fact table)              │
│   marketing/ dim_customers    (dimension table)         │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
jaffle_shop/
├── models/
│   ├── staging/
│   │   ├── jaffle_shop/
│   │   │   ├── _src_jaffle_shop.yml      # source definitions + freshness
│   │   │   ├── _stg_jaffle_shop.yml      # model docs + tests
│   │   │   ├── jaffle_shop_docs.md       # doc blocks
│   │   │   ├── stg_jaffle_shop__customers.sql
│   │   │   └── stg_jaffle_shop__orders.sql
│   │   └── stripe/
│   │       ├── _src_stripe.yml           # source definitions + freshness
│   │       ├── _stg_stripe.yml           # model docs + tests
│   │       ├── stripe_docs.md            # doc blocks
│   │       └── stg_stripe__payments.sql
│   └── marts/
│       ├── core/
│       │   ├── _core_models.yml          # model docs + tests
│       │   ├── int_orders__pivoted.sql   # intermediate — pivots payments by method
│       │   └── fail_payments.sql         # ephemeral — failed payment aggregation
│       ├── finance/
│       │   ├── _fct_orders.yml           # model docs + tests (incremental config)
│       │   └── fct_orders.sql            # incremental fact table
│       └── marketing/
│           └── dim_customers.sql
├── macros/
│   ├── _macros.yml                       # macro documentation
│   ├── cents_to_dollars.sql
│   ├── grant_select.sql
│   ├── clean_stale_models.sql
│   ├── generate_schema_name.sql
│   └── union_tables_by_prefix.sql
├── tests/
│   └── assert_positive_total_for_payments.sql   # singular test
├── packages.yml                                  # dbt packages
├── package-lock.yml
└── dbt_project.yml                               # project configuration
```

---

## 🚀 Local Setup

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- [Python 3.12](https://www.python.org/downloads/) installed
- [VSCode](https://code.visualstudio.com/) (recommended editor)

### Step 1 — Clone the Repository

```bash
git clone https://github.com/caetanovini/dbt-jaffle-shop.git
cd dbt-jaffle-shop
```

### Step 2 — Start the PostgreSQL Container

```bash
docker run --name dbt_postgres \
  -e POSTGRES_USER=dbt_user \
  -e POSTGRES_PASSWORD=dbt_password \
  -e POSTGRES_DB=dbt_learn \
  -p 5432:5432 \
  -d postgres:15
```

> ⚠️ **Note:** The container stops when you restart your PC. Run `docker start dbt_postgres` each time before working on the project.

### Step 3 — Install dbt

```bash
pip install dbt-core dbt-postgres
```

Verify:
```bash
dbt --version
```

### Step 4 — Configure profiles.yml

`profiles.yml` lives **outside** the project folder intentionally — it contains credentials and should never be committed to GitHub. Create it at `~/.dbt/profiles.yml` (`C:\Users\<YourUsername>\.dbt\profiles.yml` on Windows):

```yaml
default:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: dbt_user
      password: dbt_password
      port: 5432
      dbname: dbt_learn
      schema: dbt_schema
      threads: 4

    prod:
      type: postgres
      host: localhost
      user: dbt_user
      password: dbt_password
      port: 5432
      dbname: dbt_learn
      schema: dbt_schema_prod
      threads: 4
```

> 💡 The `target: dev` line sets the active environment. Override it anytime with `dbt run --target prod` without editing the file.

### Step 5 — Create Raw Schemas and Load Data

Connect to the PostgreSQL container:
```bash
docker exec -it dbt_postgres psql -U dbt_user -d dbt_learn
```

Create schemas:
```sql
CREATE SCHEMA jaffle_shop;
CREATE SCHEMA stripe;
```

Download and load data:
```bash
curl -o customers.csv https://dbt-tutorial-public.s3.amazonaws.com/jaffle_shop_customers.csv
curl -o orders.csv https://dbt-tutorial-public.s3.amazonaws.com/jaffle_shop_orders.csv
curl -o payments.csv https://dbt-tutorial-public.s3.amazonaws.com/stripe_payments.csv

docker cp customers.csv dbt_postgres:/customers.csv
docker cp orders.csv dbt_postgres:/orders.csv
docker cp payments.csv dbt_postgres:/payments.csv
```

Load into tables (inside psql):
```sql
CREATE TABLE jaffle_shop.customers (id INTEGER, first_name VARCHAR, last_name VARCHAR);
CREATE TABLE jaffle_shop.orders (id INTEGER, user_id INTEGER, order_date DATE, status VARCHAR, _etl_loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE stripe.payment (id INTEGER, orderid INTEGER, paymentmethod VARCHAR, status VARCHAR, amount INTEGER, created DATE, _batched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

\copy jaffle_shop.customers (id, first_name, last_name) FROM '/customers.csv' DELIMITER ',' CSV HEADER;
\copy jaffle_shop.orders (id, user_id, order_date, status) FROM '/orders.csv' DELIMITER ',' CSV HEADER;
\copy stripe.payment (id, orderid, paymentmethod, status, amount, created) FROM '/payments.csv' DELIMITER ',' CSV HEADER;
```

### Step 6 — Install dbt Packages

```bash
dbt deps
```

### Step 7 — Test the Connection

```bash
dbt debug
```

All checks should pass ✅.

### Step 8 — Run the Project

```bash
dbt build
```

---

## 🛠️ dbt Commands Reference

### `dbt debug`
**Purpose:** Validates your environment — checks that `profiles.yml` is found, the database connection works, and all dependencies are installed.

```bash
dbt debug
```

---

### `dbt deps`
**Purpose:** Downloads and installs dbt packages listed in `packages.yml`, similar to `npm install` in Node.js.

```bash
dbt deps
```

---

### `dbt run`
**Purpose:** Executes all models and materialises them in the database (as views or tables, depending on configuration).

```bash
dbt run                                     # run all models
dbt run --select customers                  # run a specific model
dbt run --select staging.*                  # run all models in staging folder

# Upstream — run dim_customers AND all models it depends on
dbt run --select +dim_customers

# Downstream — run stg_jaffle_shop__orders AND all models that depend on it
dbt run --select stg_jaffle_shop__orders+

# Both — run the model, all ancestors AND all descendants
dbt run --select +dim_customers+
```

---

### `dbt test`
**Purpose:** Runs all data tests defined in `.yml` files and the `tests/` folder.

```bash
dbt test                                    # run all tests
dbt test --select stg_stripe__payments      # test a specific model
```

---

### `dbt build`
**Purpose:** Combines `dbt run` + `dbt test` in a single command. Runs models and tests them in dependency order.

```bash
dbt build                              # build all models + run all tests
dbt build --select +dim_customers      # build upstream models + tests
dbt build --select fct_orders+         # build downstream models + tests
dbt build --select +fct_orders+        # build both directions + tests
```

### Quick Visual Guide — Upstream & Downstream
```
          stg_jaffle_shop__orders   stg_stripe__payments
                    │                        │
                    └──────────┬─────────────┘
                               ▼
                           fct_orders
                               │
                    ┌──────────┘
                    ▼
               dim_customers

+fct_orders    → stg_jaffle_shop__orders + stg_stripe__payments + fct_orders
fct_orders+    → fct_orders + dim_customers
+fct_orders+   → everything above (both directions)
```

---

### `dbt compile`
**Purpose:** Compiles Jinja SQL into raw SQL without executing it.

> ⚠️ Works for **models only** — macros are functions, not DAG nodes, and cannot be compiled with `--select`.

```bash
dbt compile
dbt compile --select stg_stripe__payments
```
Compiled SQL appears in `target/compiled/`.

---

### `dbt run-operation`
**Purpose:** Executes a macro directly from the terminal without attaching it to a model. Used for administrative tasks.

```bash
dbt run-operation grant_select
dbt run-operation grant_select --args "{'schema_name': 'dbt_schema', 'user_name': 'dbt_user'}"
dbt run-operation clean_stale_models --args "{'dry_run': False}"
```

---

### `dbt source freshness`
**Purpose:** Checks whether source data is up to date based on timestamp thresholds defined in `_src_*.yml` files. Returns `PASS`, `WARN`, or `ERROR STALE`.

```bash
dbt source freshness
```

---

### `dbt docs generate` + `dbt docs serve`
**Purpose:** Generates a full documentation site including model descriptions, column definitions, and a lineage graph.

```bash
dbt docs generate    # builds the docs site
dbt docs serve       # opens it in your browser at localhost:8080
```

---

### Command Comparison

| Command | Compiles | Runs Models | Runs Tests | Runs Macros | Checks Sources |
|---------|----------|-------------|------------|-------------|----------------|
| `dbt compile` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `dbt run` | ✅ | ✅ | ❌ | ❌ | ❌ |
| `dbt test` | ✅ | ❌ | ✅ | ❌ | ❌ |
| `dbt build` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `dbt run-operation` | ✅ | ❌ | ❌ | ✅ | ❌ |
| `dbt source freshness` | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 📚 Key dbt Concepts

### Generic Tests vs Singular Tests

**Generic tests** are reusable and defined in `.yml` files:
```yaml
columns:
  - name: order_id
    tests:
      - unique
      - not_null
      - accepted_values:
          values: ['placed', 'shipped', 'completed', 'return_pending', 'returned']
      - relationships:
          to: ref('stg_jaffle_shop__customers')
          field: customer_id
```

**Singular tests** are custom SQL files in the `tests/` folder that return rows which **fail** the test:
```sql
-- tests/assert_positive_total_for_payments.sql
select
    order_id,
    sum(amount) as total_amount
from {{ ref('stg_stripe__payments') }}
group by 1
having sum(amount) < 0
```

### Materialisation Types

See the full [Materialization Fundamentals](#-materialization-fundamentals) section for detailed explanations, trade-offs, and configuration options.

| Type | Description | Best For |
|------|-------------|----------|
| `view` | Query stored, no data written | Staging models |
| `table` | Data physically stored | Marts / heavy queries |
| `incremental` | Only processes new records | Large, append-only datasets |
| `ephemeral` | Exists only as a CTE, never in the database | Reusable snippets, intermediate logic |

### Doc Blocks

Doc blocks allow writing rich markdown descriptions in `.md` files and reusing them across models:

```markdown
{% docs payment_method %}
The payment method used by the customer.
Possible values: `credit_card`, `coupon`, `bank_transfer`, `gift_card`
{% enddocs %}
```

Referenced in `.yml`:
```yaml
- name: payment_method
  description: "{{ doc('payment_method') }}"
```

---

## 🗂️ Data Layers Explained

### Source Layer
Raw data loaded by external tools. Sources are defined in `_src_*.yml` files using the `source()` function and are **never modified** by dbt.

### Staging Layer (`models/staging/`)
One-to-one models with source tables. Each staging model renames columns, casts data types, applies basic cleaning, and adds **no business logic**. Materialised as **views**.

### Intermediate Layer (`models/intermediate/`) *(not used in this project)*
Optional layer for complex joins that would make mart models too long. Helps keep marts readable by breaking logic into reusable pieces.

### Marts Layer (`models/marts/`)
Business-facing models ready for BI tools. Organised by domain:
- `finance/fct_orders` — fact table with one row per order and payment amount
- `marketing/dim_customers` — dimension table with customer lifetime metrics

Materialised as **tables** for query performance.

---

## 🧩 Jinja, Macros & Packages

This section covers concepts from the **dbt Jinja, Macros, and Packages** course.

---

### Jinja Templating

dbt uses **Jinja** — a Python templating language — to make SQL dynamic and reusable. All Jinja expressions use these delimiters:

```
{{ expression }}   →  outputs a value        e.g. {{ ref('my_model') }}
{% statement %}    →  logic / control flow   e.g. {% if %}, {% for %}
{# comment #}      →  ignored by dbt
{%- -%}            →  strips surrounding whitespace (keeps compiled SQL clean)
```

---

#### `{% set %}` — Defining Variables

Declares and assigns variables inside macros or models:

```sql
-- Simple variable
{% set my_schema = 'dbt_schema' %}

-- Multi-line SQL stored as a variable
{% set my_query %}
    select * from jaffle_shop.orders where status = 'completed'
{% endset %}

{% do run_query(my_query) %}
```

---

#### `{% for %}` — Looping

Iterates over a list to generate repetitive SQL dynamically:

```sql
{% set payment_methods = ['credit_card', 'coupon', 'bank_transfer', 'gift_card'] %}

select
    order_id,
    {% for method in payment_methods %}
        sum(case when payment_method = '{{ method }}' then amount else 0 end)
            as {{ method }}_amount
        {%- if not loop.last %},{% endif %}
    {% endfor %}
from {{ ref('stg_stripe__payments') }}
group by 1
```

`loop.last` returns `True` on the final iteration — used to avoid trailing commas.

---

#### `{% if %}` — Conditional Logic

Writes environment-aware or conditional SQL:

```sql
{% if target.name == 'dev' %}
    select * from {{ ref('stg_jaffle_shop__orders') }} limit 100
{% else %}
    select * from {{ ref('stg_jaffle_shop__orders') }}
{% endif %}
```

---

#### dbt Native Functions — `run_query()`, `log()` and `target`

These are part of **dbt's native Jinja context** — automatically available in every macro and model without any imports:

| Name | Type | Purpose |
|---|---|---|
| `run_query(sql)` | Function | Executes SQL and returns results as an `agate.Table` |
| `log(msg, info=True)` | Function | Prints a message to the terminal |
| `env_var(name, default)` | Function | Reads an OS environment variable with optional fallback |
| `ref()` | Function | References another dbt model |
| `source()` | Function | References a raw source table |
| `target` | Variable | Contains current connection details from `profiles.yml` |
| `this` | Variable | References the current model being built |

```sql
-- target variable properties
target.schema    → 'dbt_schema'    (from profiles.yml)
target.database  → 'dbt_learn'     (from profiles.yml)
target.user      → 'dbt_user'      (from profiles.yml)
target.type      → 'postgres'      (adapter type)
target.name      → 'dev'           (active target name)
```

> ⚠️ `target.role` is **Snowflake-only** and returns `None` in PostgreSQL. Use `target.user` instead.

---

### Macros

Macros are reusable Jinja functions defined in `.sql` files inside `macros/`. Structure:

```sql
{% macro macro_name(argument1, argument2='default_value') %}
    -- logic here
{% endmacro %}
```

Called inside a model:
```sql
select {{ cents_to_dollars('amount') }} as amount
from {{ ref('stg_stripe__payments') }}
```

Called from the terminal:
```bash
dbt run-operation macro_name --args "{'argument1': 'value'}"
```

> ⚠️ Macros are **not DAG nodes** — `dbt compile --select` does not work for macros. Use `dbt run-operation` to execute them.

---

#### `cents_to_dollars`
Converts a monetary value from cents to dollars using `round()`.

```sql
select {{ cents_to_dollars('amount') }} as amount          -- 2 decimal places (default)
select {{ cents_to_dollars('amount', 4) }} as amount       -- 4 decimal places
```

---

#### `grant_select`
Grants `USAGE` on a schema and `SELECT` on all tables to a PostgreSQL user.

> **PostgreSQL adaptation:** Snowflake uses `GRANT ... TO ROLE`. PostgreSQL uses `GRANT ... TO <user>` and covers views under `all tables`.

```bash
dbt run-operation grant_select
dbt run-operation grant_select --args "{'schema_name': 'dbt_schema', 'user_name': 'analyst'}"
```

---

#### `clean_stale_models`
Identifies and optionally drops stale tables and views. Supports `dry_run` mode (default `True`) to safely preview DROP commands before executing.

> **PostgreSQL adaptation:** Uses `information_schema.views` instead of the Snowflake-specific `pg_stat_user_views`.

```bash
dbt run-operation clean_stale_models                          # preview only (dry_run=True)
dbt run-operation clean_stale_models --args "{'dry_run': False}"  # actually drop objects
```

---

#### `generate_schema_name`
Overrides dbt's default schema name logic for multi-environment deployments. In `dev`, all models write to the default target schema. In `prod`, models use their configured custom schema.

```bash
$env:DBT_ENV_NAME = "prod"   # PowerShell — prod uses custom schema names
$env:DBT_ENV_NAME = "dev"    # dev always uses default schema (safe sandbox)
```

---

#### `union_tables_by_prefix`
Dynamically unions all tables in a schema sharing a common name prefix using `dbt_utils.get_relations_by_prefix`.

```sql
-- Unions all tables starting with 'events_'
{{ union_tables_by_prefix('dbt_learn', 'dbt_schema', 'events_') }}
```

---

### Packages

dbt packages are installed via `packages.yml` and downloaded with `dbt deps`. They can provide **macros only** or **macros + pre-built models**.

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.3.0
  - package: dbt-labs/codegen
    version: 0.13.1
```

When a package includes models, control whether they run in `dbt_project.yml`:
```yaml
models:
  package_with_models:
    enabled: true    # run this package's models alongside yours
```

---

#### `dbt_utils.date_spine`
Generates a complete sequence of dates between two points — ensures no gaps in time series analysis.

```sql
{{ dbt_utils.date_spine(
    datepart = "day",
    start_date = "cast('2018-01-01' as date)",
    end_date = "cast('2018-12-31' as date)"
) }}
```

---

#### `dbt_utils.generate_surrogate_key`
Generates a deterministic hash key from one or more columns — creates reliable unique identifiers when no natural primary key exists.

```sql
select
    {{ dbt_utils.generate_surrogate_key(['order_id', 'payment_method']) }} as surrogate_key,
    order_id,
    payment_method
from {{ ref('stg_stripe__payments') }}
```

> ⚠️ Returns `null` if **any** input column is null — always pair with a `not_null` test.

---

#### `dbt_utils.get_relations_by_prefix`
Returns a list of all relations in a schema matching a given prefix. Used in the `union_tables_by_prefix` macro.

```sql
{% set tables = dbt_utils.get_relations_by_prefix(
    database = 'dbt_learn',
    schema = 'dbt_schema',
    prefix = 'stg_'
) %}

{% for table in tables %}
    select * from {{ table }}
    {% if not loop.last %} union all {% endif %}
{% endfor %}
```

---

## 🧱 Materialization Fundamentals

This section covers concepts from the **dbt Materialization Fundamentals** course.

---

### What is a Materialisation?

A materialisation defines **how dbt writes a model's results into the database**. Choosing the right materialisation is a critical performance and cost decision — it determines whether data is stored on disk, recomputed on every query, or never written to the database at all.

---

### The Four Materialisation Types

#### `view` — Virtual Table
The SQL query is stored on disk but **no data is physically written**. Every time the view is queried, the SQL runs from scratch.

```sql
{{ config(materialized='view') }}

select * from {{ ref('stg_jaffle_shop__orders') }}
```

| | |
|---|---|
| Build speed | ✅ Fast — only stores the query definition |
| Query speed | ⚠️ Slower — reruns SQL on every access |
| Storage | ✅ Minimal |
| Best for | Staging models, lightweight transformations |

---

#### `table` — Physical Table
Data is computed and **physically written to the database**. Every `dbt run` recreates the table from scratch.

```sql
{{ config(materialized='table') }}

select * from {{ ref('fct_orders') }}
```

| | |
|---|---|
| Build speed | ⚠️ Slower — reads and writes all data |
| Query speed | ✅ Fast — data is pre-computed and stored |
| Storage | ⚠️ Uses disk space |
| Best for | Mart models, heavily queried datasets |

---

#### `ephemeral` — No Database Object
The model **does not exist in the database at all**. dbt compiles it as a CTE (Common Table Expression) and injects it directly into any downstream model that references it.

```sql
{{ config(materialized='ephemeral') }}

select
    payment_method,
    status,
    sum(amount) as amount
from {{ ref('stg_stripe__payments') }}
where status = 'fail'
group by 1, 2
```

| | |
|---|---|
| Build speed | ✅ Instant — nothing is written |
| Query speed | ⚠️ Increases build time of downstream models |
| Storage | ✅ Zero — no database object created |
| Best for | Reusable SQL snippets, intermediate logic that doesn't need to be queried directly |

> ⚠️ **Important:** Ephemeral models **cannot be queried directly** in the database and **cannot be run** with `dbt run --select`. Use `dbt compile --select model_name` to inspect the generated CTE.

**How it works under the hood:**

When a downstream model references an ephemeral model via `ref()`, dbt replaces it with a CTE at compile time:

```sql
-- Your model references ref('fail_payments')
select * from {{ ref('fail_payments') }}

-- dbt compiles this to:
with fail_payments as (
    select
        payment_method,
        status,
        sum(amount) as amount
    from dbt_schema.stg_stripe__payments
    where status = 'fail'
    group by 1, 2
)
select * from fail_payments
```

---

#### `incremental` — Append Only
Only processes **new or updated records** since the last run, instead of rebuilding the entire table. Ideal for large datasets where full refreshes are too slow or expensive.

```sql
{{ config(materialized='incremental') }}

select * from {{ ref('stg_jaffle_shop__orders') }}

{% if is_incremental() %}
    where order_date > (select max(order_date) from {{ this }})
{% endif %}
```

> `{{ this }}` refers to the current model's existing table in the database. `is_incremental()` returns `True` when the table already exists and dbt is running in incremental mode.

---

### How to Configure Materialisations

There are **four ways** to set a materialisation, listed from lowest to highest priority (higher priority overrides lower):

**1. `dbt_project.yml` — applies to all models in a folder:**
```yaml
models:
  jaffle_shop:
    staging:
      +materialized: view      # all staging models → view
    marts:
      +materialized: table     # all mart models → table
```

**2. `schema.yml` / properties file — applies to a specific model:**
```yaml
models:
  - name: dim_customers
    config:
      materialized: table
```

**3. Model-level `schema.yml` inside a subfolder** *(same as above, scoped to that folder)*

**4. `{{ config() }}` block inside the model file — highest priority, overrides everything:**
```sql
{{ config(materialized='ephemeral') }}

select ...
```

> 💡 The `{{ config() }}` block at the model level always wins. This is useful when you need one model to behave differently from the folder default.

---

### Materialisation Comparison

| | `view` | `table` | `ephemeral` | `incremental` |
|---|---|---|---|---|
| Exists in database | ✅ As view | ✅ As table | ❌ Never | ✅ As table |
| Data stored on disk | ❌ | ✅ | ❌ | ✅ |
| Build speed | ✅ Fast | ⚠️ Slow | ✅ Instant | ✅ Fast (after first run) |
| Query speed | ⚠️ Slow | ✅ Fast | N/A | ✅ Fast |
| Can query directly | ✅ | ✅ | ❌ | ✅ |
| Best for | Staging | Marts | Reusable snippets | Large append-only data |

---

### Models in This Project — `marts/core/`

Two new models were added to illustrate these concepts:

**`int_orders__pivoted`** — Intermediate model that dynamically pivots payment amounts by method using a Jinja `for` loop. Only includes successful payments. Demonstrates how Jinja and materialisations work together.

**`fail_payments`** — Ephemeral model aggregating failed payments by method and status. Demonstrates the `ephemeral` materialisation — this model never appears in the database but can be referenced by downstream models as a reusable CTE.

---

## 🔄 Incremental Models

This section covers concepts from the **dbt Incremental Models** course.

---

### What is an Incremental Model?

An incremental model is a **table that only processes new or updated records** on each run, instead of rebuilding the entire table from scratch. This makes them dramatically faster and cheaper for large datasets.

```
Full refresh (table materialisation)     Incremental run
─────────────────────────────────────    ────────────────────────────
Reads ALL records every run              Only reads NEW records
100M rows → processes 100M rows          100M rows + 1000 new → processes 1000
Slow and expensive                       Fast and cheap
```

---

### Basic Configuration

```sql
{{
    config(
        materialized = 'incremental',
        unique_key = 'order_id',
        incremental_strategy = 'merge'
    )
}}

select * from {{ ref('stg_jaffle_shop__orders') }}

{% if is_incremental() %}
    where order_date >= (select max(order_date) from {{ this }})
{% endif %}
```

**Key components:**

`is_incremental()` — returns `True` when the table already exists and dbt is running in incremental mode. The `WHERE` clause inside this block filters to only new records on subsequent runs. On the first run, `is_incremental()` is `False` and the full table is built.

`{{ this }}` — refers to the **current model's existing table** in the database. Used to find the maximum existing date so dbt knows where to start processing from.

`unique_key` — the column dbt uses to identify and match existing rows when merging. Prevents duplicates when reprocessing overlapping records.

---

### Incremental Strategies

The `incremental_strategy` config controls **how dbt updates existing rows**:

#### `append`
Only inserts new rows — never updates existing ones. Fastest strategy but risks duplicates if records can be reprocessed.

```sql
{{ config(materialized='incremental', incremental_strategy='append') }}
```

Best for: event logs, immutable data where records never change.

---

#### `merge` *(used in this project)*
Inserts new rows AND updates existing rows that match the `unique_key`. The most common strategy for fact tables where records can be updated.

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge'
) }}
```

Best for: fact tables with mutable records like orders or payments.

> ✅ Despite being commonly associated with Snowflake/BigQuery, `merge` also works in PostgreSQL as confirmed during this project.

---

#### `delete+insert`
Deletes rows matching the `unique_key` then reinserts them. PostgreSQL's native alternative to `merge`.

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='delete+insert'
) }}
```

Best for: PostgreSQL when `merge` behaviour is needed.

---

#### `insert_overwrite`
Replaces entire partitions of data rather than individual rows. Requires a partition configuration.

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by={'field': 'order_date', 'data_type': 'date'}
) }}
```

Best for: BigQuery and Spark with date-partitioned tables.

---

#### `microbatch`
Processes data in small time-based batches. Designed for very large datasets where even a standard incremental filter would process too much data at once.

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='order_date',
    batch_size='day'
) }}
```

Best for: extremely large time-series datasets.

---

### Strategy Comparison

| Strategy | Inserts new | Updates existing | Deletes | Best for |
|---|---|---|---|---|
| `append` | ✅ | ❌ | ❌ | Immutable event logs |
| `merge` | ✅ | ✅ | ❌ | Mutable fact tables |
| `delete+insert` | ✅ | ✅ (via delete) | ✅ | PostgreSQL alternative to merge |
| `insert_overwrite` | ✅ | ✅ (via partition) | ✅ | Partitioned tables (BigQuery/Spark) |
| `microbatch` | ✅ | ✅ | ❌ | Very large time-series data |

---

### `on_schema_change`

Controls what happens when the **columns in your incremental model change** between runs — for example, when you add a new column to your SELECT statement.

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    on_schema_change='append_new_columns'
) }}
```

| Option | Behaviour |
|---|---|
| `'ignore'` | Default. Ignores schema changes — new columns are not added to the existing table |
| `'fail'` | Raises an error if the schema changes — forces you to handle it explicitly |
| `'append_new_columns'` | Adds new columns to the existing table, keeps old columns intact |
| `'sync_all_columns'` | Adds new columns AND removes deleted columns — fully syncs the schema |

> ⚠️ Use `'sync_all_columns'` carefully — removing columns from an incremental model will **drop those columns** from the existing table in the database.

---

### Full Refresh

Force a complete rebuild of an incremental model at any time:

```bash
dbt run --full-refresh --select fct_orders
dbt build --full-refresh                    # full refresh all models
```

Useful when you need to reprocess historical data or after a significant schema change.

---

## 🔁 CI/CD with dbt

### What is CI/CD?

**CI (Continuous Integration)** automatically validates every code change before it reaches production. In dbt, a CI job runs `dbt build` on a Pull Request to catch errors before merging.

**CD (Continuous Deployment)** automatically deploys validated code to production after a merge.

```
Developer opens PR
        ↓
CI job runs automatically
        ↓
dbt builds modified models into a PR-specific schema (e.g. pr_123_schema)
        ↓
Tests run against the new models
        ↓
PR approved → merge to main → CD deploys to production
```

---

### Slim CI — `state:modified+`

Running a full `dbt build` on every PR would be slow and expensive — it would rebuild every model even if you only changed one file. **Slim CI** solves this by only building what changed:

```bash
dbt build --select state:modified+
```

| Selector | Meaning |
|---|---|
| `state:modified` | only models whose code changed since last production run |
| `state:modified+` | changed models AND all their downstream dependencies |

dbt compares your PR code against the production **manifest.json** (a snapshot of your last production run) to determine what changed.

---

### The Incremental Model Problem in CI

When a CI job runs `dbt build --select state:modified+` and `fct_orders` is in the selection:

```
CI checks: does fct_orders exist in pr_123_schema?
                        ↓
                     NO ❌ (it's a fresh schema!)
                        ↓
           is_incremental() = False
                        ↓
           Full rebuild of ALL historical data 😢
           (slow, expensive, defeats the purpose of incremental)
```

---

### The Fix — Two-Step CI for Incremental Models

```bash
# Step 1 — Clone existing incremental models from production into the PR schema
dbt clone --select state:modified+,config.materialized:incremental,state:old

# Step 2 — Build all modified models and their dependencies
dbt build --select state:modified+
```

**What `dbt clone` does:** Creates a **lightweight pointer** (not a data copy) from the PR schema to the production table. This makes `is_incremental()` return `True` on Step 2, so dbt only processes new records instead of rebuilding everything.

**Decoding the clone selector:**

| Part | Meaning |
|---|---|
| `state:modified+` | modified models and their downstream dependencies |
| `config.materialized:incremental` | only the incremental models from that set |
| `state:old` | only models that already exist in production (excludes brand new models) |

`state:old` is critical — without it, dbt would try to clone a model that doesn't exist in production yet and throw an error.

---

### Full CI/CD Flow with Incremental Models

```
PR opened
    ↓
Step 1: dbt clone --select state:modified+,config.materialized:incremental,state:old
    → fct_orders cloned from prod into pr_123_schema (lightweight pointer, no data copy)
    ↓
Step 2: dbt build --select state:modified+
    → fct_orders: is_incremental() = True → only processes new records ⚡
    → other modified models: built normally
    ↓
All tests pass ✅
    ↓
PR merged → production deployment runs full dbt build
```

---

## 🌍 Environments — Dev & Prod

### What is an Environment in dbt?

An environment is a **named output block** in `profiles.yml` that defines a specific database connection. Environments allow the same dbt project to run safely against different schemas without changing any SQL.

```
profiles.yml
    ├── dev   → schema: dbt_schema       (your personal sandbox)
    └── prod  → schema: dbt_schema_prod  (production data)
```

---

### Why `profiles.yml` Lives Outside the Project

```
profiles.yml (outside repo)          dbt_project.yml (inside repo)
────────────────────────────         ──────────────────────────────
Contains credentials 🔒              Contains project logic ✅
Machine-specific                     Shared with the team
NEVER committed to GitHub            Always committed to GitHub
Different per developer              Same for everyone
```

Every developer has their **own** `profiles.yml` — but everyone shares the same `dbt_project.yml`.

---

### Setting Up Dev and Prod

```yaml
# ~/.dbt/profiles.yml  (C:\Users\<username>\.dbt\profiles.yml on Windows)
default:
  target: dev                    # active environment
  outputs:

    dev:
      type: postgres
      host: localhost
      user: dbt_user
      password: dbt_password
      port: 5432
      dbname: dbt_learn
      schema: dbt_schema         # dev models write here
      threads: 4

    prod:
      type: postgres
      host: localhost            # in real projects: a different server
      user: dbt_user
      password: dbt_password
      port: 5432
      dbname: dbt_learn
      schema: dbt_schema_prod    # prod models write here
      threads: 4
```

---

### Switching Between Environments

```bash
dbt run                  # uses default target (dev)
dbt run --target dev     # explicitly target dev
dbt run --target prod    # run against prod
dbt debug                # shows which target is currently active
```

---

### Environment-Aware Code

```sql
-- Limit rows in dev to speed up development
{% if target.name == 'dev' %}
    select * from {{ ref('stg_jaffle_shop__orders') }} limit 100
{% else %}
    select * from {{ ref('stg_jaffle_shop__orders') }}
{% endif %}
```

The `generate_schema_name` macro uses `DBT_ENV_NAME` for schema routing:
```bash
$env:DBT_ENV_NAME = "dev"    # → all models write to default schema (safe)
$env:DBT_ENV_NAME = "prod"   # → models use their configured custom schemas
```

---

### `target` Variable Quick Reference

| Variable | Example Value | Notes |
|---|---|---|
| `target.name` | `'dev'` | Active target name |
| `target.schema` | `'dbt_schema'` | From `schema:` in profiles.yml |
| `target.database` | `'dbt_learn'` | From `dbname:` in profiles.yml |
| `target.user` | `'dbt_user'` | From `user:` in profiles.yml |
| `target.type` | `'postgres'` | Adapter type |
| `target.role` | `None` ⚠️ | Snowflake only — use `target.user` in PostgreSQL |

---

## 🔗 `ref()` and `source()` Functions

### `{{ source('source_name', 'table_name') }}`

References **raw source tables** dbt does not own. Defined in `_src_*.yml` files.

```sql
from {{ source('jaffle_shop', 'customers') }}
-- resolves to: dbt_learn.jaffle_shop.customers
```

**Benefits:** enables freshness checks, appears in lineage graph, centralises source config.

### `{{ ref('model_name') }}`

References **other dbt models** — the core of dbt's DAG.

```sql
with orders as (select * from {{ ref('stg_jaffle_shop__orders') }}),
payments as (select * from {{ ref('stg_stripe__payments') }})
```

| | Hardcoded | `ref()` |
|---|---|---|
| Dependency tracking | ❌ | ✅ dbt builds the DAG |
| Execution order | ❌ Manual | ✅ Automatic |
| Environment switching | ❌ Must update SQL | ✅ Resolves automatically |
| Lineage graph | ❌ Not visible | ✅ Fully visible |

---

## ⚙️ Snowflake vs PostgreSQL Differences

This project was originally designed for **Snowflake** but adapted to run on **PostgreSQL**. All differences encountered are documented below.

### Architecture

| Feature | Snowflake | PostgreSQL (this project) |
|---------|-----------|--------------------------|
| Database hierarchy | `database.schema.table` | Single database, multiple schemas |
| Compute layer | `CREATE WAREHOUSE` | Not needed — Postgres manages compute automatically |
| Cross-database queries | ✅ Easy | ❌ Not supported — use multiple schemas instead |
| Loading from S3 | `COPY INTO ... FROM 's3://...'` | Manual CSV download + `\copy` |

**Schema mapping:**
```
Snowflake: raw.jaffle_shop.customers
PostgreSQL: dbt_learn (db) → jaffle_shop (schema) → customers (table)
```

---

### SQL Syntax

| Feature | Snowflake | PostgreSQL |
|---------|-----------|------------|
| Column alias in `HAVING` | ✅ `having total_amount < 0` | ❌ Must repeat expression: `having sum(amount) < 0` |
| Grant syntax | `GRANT ... TO ROLE role_name` | `GRANT ... TO user_name` (no `ROLE` keyword) |
| Grant on views | `GRANT SELECT ON ALL VIEWS...` | ❌ Not valid — views are included in `ALL TABLES` |

---

### dbt Target Variables

| Variable | Snowflake | PostgreSQL |
|---------|-----------|------------|
| `target.schema` | ✅ Available | ✅ Available |
| `target.database` | ✅ Available | ✅ Available |
| `target.user` | ✅ Available | ✅ Available |
| `target.role` | ✅ Available | ❌ Returns `None` — use `target.user` |
| `target.warehouse` | ✅ Available | ❌ Returns `None` |

---

### System Catalog Tables

| Purpose | Snowflake | PostgreSQL |
|---------|-----------|------------|
| List views | `pg_stat_user_views` | `information_schema.views` |
| List tables | `pg_stat_user_tables` | `pg_stat_user_tables` ✅ |

---

### dbt-fusion vs dbt-core

The dbt VSCode Extension installs **dbt-fusion** by default. However, dbt-fusion does not yet support PostgreSQL on Windows. This project uses **dbt-core** instead.

| | dbt-fusion | dbt-core |
|---|---|---|
| PostgreSQL on Windows | ❌ Broken | ✅ Works |
| Status | Preview / experimental | Stable |
| Installed as | Standalone `.exe` | Python package via `pip` |
| Certification alignment | ❌ | ✅ |

If dbt-fusion reinstalls itself via the VSCode extension, remove it with:
```powershell
Remove-Item C:\Users\<username>\.local\bin\dbt.exe -Force
```

---

## 📖 Resources

- [dbt Fundamentals Course](https://learn.getdbt.com/) — Official dbt Learning platform
- [dbt Jinja, Macros & Packages Course](https://learn.getdbt.com/) — Official dbt Learning platform
- [dbt Materialization Fundamentals Course](https://learn.getdbt.com/) — Official dbt Learning platform
- [dbt Incremental Models Course](https://learn.getdbt.com/) — Official dbt Learning platform
- [dbt Documentation](https://docs.getdbt.com/) — Full reference docs
- [dbt Jinja Context Reference](https://docs.getdbt.com/reference/dbt-jinja-functions) — All native functions and variables
- [dbt_utils Package](https://hub.getdbt.com/dbt-labs/dbt_utils/latest/) — dbt_utils macro reference
- [dbt Community Slack](https://www.getdbt.com/community/) — 100k+ data professionals
- [dbt Best Practices](https://docs.getdbt.com/best-practices) — Official style guide
- [PostgreSQL Documentation](https://www.postgresql.org/docs/) — PostgreSQL reference

---

## 👤 About

Built by **Vinícius Caetano** as part of preparation for the **dbt Analytics Engineering Certification**.

This project demonstrates hands-on experience with dbt fundamentals including data modelling, testing, documentation, source management, Jinja templating, macros, packages, materialisation strategies, incremental models, CI/CD concepts, and multi-environment setup using an open-source stack.