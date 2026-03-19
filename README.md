# 🏪 Jaffle Shop — dbt Fundamentals Project

> This project was built as part of the **[dbt Fundamentals (VSCode)](https://learn.getdbt.com/)** course, available on the official dbt Learning platform. It demonstrates core analytics engineering concepts using **dbt-core** with a **PostgreSQL** database running on **Docker**, adapted from the original Snowflake-based course.

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Data Architecture](#-data-architecture)
- [Project Structure](#-project-structure)
- [Local Setup](#-local-setup)
- [dbt Commands Reference](#-dbt-commands-reference)
- [Key dbt Concepts](#-key-dbt-concepts)
- [Data Layers Explained](#-data-layers-explained)
- [ref() and source() Functions](#-ref-and-source-functions)
- [Snowflake vs PostgreSQL Differences](#-snowflake-vs-postgresql-differences)

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
│   │       ├── _stg_stipe.yml            # model docs + tests
│   │       ├── stipe_docs.md             # doc blocks
│   │       └── stg_stripe__payments.sql
│   └── marts/
│       ├── finance/
│       │   └── fct_orders.sql
│       └── marketing/
│           └── dim_customers.sql
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

Create the file `~/.dbt/profiles.yml` (outside the project folder):

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
```

> ⚠️ `profiles.yml` is stored **outside** the project directory intentionally — it contains credentials and should never be committed to GitHub.

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
# Download CSVs
curl -o customers.csv https://dbt-tutorial-public.s3.amazonaws.com/jaffle_shop_customers.csv
curl -o orders.csv https://dbt-tutorial-public.s3.amazonaws.com/jaffle_shop_orders.csv
curl -o payments.csv https://dbt-tutorial-public.s3.amazonaws.com/stripe_payments.csv

# Copy into container
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

These are the core dbt commands used throughout this project:

### `dbt debug`
**Purpose:** Validates your environment — checks that `profiles.yml` is found, the database connection works, and all dependencies are installed.

**When to use:** Always run this first when setting up the project or troubleshooting connection issues.

```bash
dbt debug
```

---

### `dbt deps`
**Purpose:** Downloads and installs dbt packages listed in `packages.yml`, similar to `npm install` in Node.js.

**When to use:** After cloning the repo for the first time, or after adding a new package.

```bash
dbt deps
```

---

### `dbt run`
**Purpose:** Executes all models and materialises them in the database (as views or tables, depending on configuration).

**When to use:** When you want to build or rebuild your models.

```bash
dbt run                              # run all models
dbt run --select customers           # run a specific model
dbt run --select staging.*           # run all models in staging folder

# Upstream models (dependencies) — everything dim_customers depends on
dbt run --select +dim_customers      # run dim_customers AND all its upstream models

# Downstream models (dependents) — everything that depends on stg_jaffle_shop__orders
dbt run --select stg_jaffle_shop__orders+   # run stg_jaffle_shop__orders AND all downstream models

# Both upstream and downstream together
dbt run --select +stg_jaffle_shop__customers+     # run stg_jaffle_shop__customers, all its ancestors AND all its descendants
```

---

### `dbt test`
**Purpose:** Runs all data tests defined in your `.yml` files and `tests/` folder. Returns rows that violate the test condition — if rows are returned, the test fails.

**When to use:** After `dbt run`, to validate data quality.

```bash
dbt test                                    # run all tests
dbt test --select stg_stripe__payments      # test a specific model
```

---

### `dbt build`
**Purpose:** Combines `dbt run` + `dbt test` in a single command. Runs models and tests them in dependency order.

**When to use:** The preferred command for day-to-day development — ensures models and tests always run together.

```bash
dbt build                              # build all models + run all tests
dbt build --select customers           # build a specific model + its tests

# Upstream models
dbt build --select +dim_customers      # build dim_customers AND all its upstream models + tests

# Downstream models
dbt build --select fct_orders+         # build fct_orders AND all downstream models + tests

# Both upstream and downstream together
dbt build --select +fct_orders+        # build fct_orders, all ancestors AND all descendants + tests
```

---

## 💡 Quick Visual Guide
```
                    stg_jaffle_shop__orders   stg_stripe__payments
                              │                        │
                              └──────────┬─────────────┘
                                         ▼
                                     fct_orders          ← --select fct_orders
                                         │
                              ┌──────────┘
                              ▼
                         dim_customers

+fct_orders   → stg_jaffle_shop__orders + stg_stripe__payments + fct_orders (upstream)
fct_orders+   → fct_orders + dim_customers (downstream)
+fct_orders+  → everything above (both directions)
```

---

### `dbt compile`
**Purpose:** Compiles Jinja SQL into raw SQL without executing it. Useful for inspecting what SQL dbt will actually run.

**When to use:** When debugging Jinja templating or verifying compiled SQL before running.

```bash
dbt compile
```
Compiled SQL appears in `target/compiled/`.

---

### `dbt source freshness`
**Purpose:** Checks whether source data is up to date based on timestamp thresholds defined in `_src_*.yml` files. Returns `PASS`, `WARN`, or `ERROR STALE`.

**When to use:** In production pipelines to detect stale or delayed data loads.

```bash
dbt source freshness
```

---

### `dbt docs generate` + `dbt docs serve`
**Purpose:** Generates a full documentation site for your project, including model descriptions, column definitions, and a lineage graph.

**When to use:** When you want to explore or share your project's documentation.

```bash
dbt docs generate    # builds the docs site
dbt docs serve       # opens it in your browser at localhost:8080
```

---

### Command Comparison

| Command | Compiles | Runs Models | Runs Tests | Checks Sources |
|---------|----------|-------------|------------|----------------|
| `dbt compile` | ✅ | ❌ | ❌ | ❌ |
| `dbt run` | ✅ | ✅ | ❌ | ❌ |
| `dbt test` | ✅ | ❌ | ✅ | ❌ |
| `dbt build` | ✅ | ✅ | ✅ | ❌ |
| `dbt source freshness` | ❌ | ❌ | ❌ | ✅ |

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

**Singular tests** are custom SQL files in the `tests/` folder. They return rows that **fail** the test:
```sql
-- tests/assert_positive_total_for_payments.sql
-- Returns orders with negative total amounts (should never happen)
select
    order_id,
    sum(amount) as total_amount
from {{ ref('stg_stripe__payments') }}
group by 1
having sum(amount) < 0
```

### Materialisation Types

| Type | Description | Best For |
|------|-------------|----------|
| `view` | Query runs on every access | Staging models |
| `table` | Data physically stored | Marts / heavy queries |
| `incremental` | Only processes new records | Large, append-only datasets |
| `ephemeral` | Exists only as a CTE, not in database | Intermediate logic |

Configured in `dbt_project.yml`:
```yaml
models:
  jaffle_shop:
    staging:
      +materialized: view
    marts:
      +materialized: table
```

### Doc Blocks

Doc blocks allow you to write rich markdown descriptions in `.md` files and reuse them across models:

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

Analytics engineering best practice organises data into distinct layers, each with a specific purpose:

### Source Layer
Raw data loaded by external tools (ETL pipelines, Fivetran, Airbyte, etc.). In this project, these are the `jaffle_shop` and `stripe` schemas in PostgreSQL. Sources are defined in `_src_*.yml` files using the `source()` function — they are **never modified**.

### Staging Layer (`models/staging/`)
One-to-one models with source tables. Each staging model:
- Renames columns to consistent naming conventions (`id` → `customer_id`)
- Casts data types
- Applies basic cleaning (e.g. `amount/100` to convert cents to dollars)
- Adds **no business logic**

Materialised as **views** since they are lightweight transformations.

### Intermediate Layer (`models/intermediate/`) *(not used in this project)*
Optional layer for complex joins or aggregations that would make mart models too long. Helps keep mart models readable by breaking logic into reusable pieces.

### Marts Layer (`models/marts/`)
Business-facing models ready for consumption by analysts and BI tools. Organised by business domain:
- `finance/fct_orders` — fact table with one row per order and its payment amount
- `marketing/dim_customers` — dimension table with customer lifetime metrics

Materialised as **tables** for query performance.

---

## 🔗 `ref()` and `source()` Functions

These two Jinja functions are the foundation of dbt's dependency management.

### `{{ source('source_name', 'table_name') }}`

Used to reference **raw source tables** that dbt does not own or manage. Defined in `_src_*.yml` files.

```sql
-- models/staging/jaffle_shop/stg_jaffle_shop__customers.sql
select
    id as customer_id,
    first_name,
    last_name
from {{ source('jaffle_shop', 'customers') }}
--    ^^^^^^^^^^  maps to _src_jaffle_shop.yml → schema: jaffle_shop → table: customers
```

**Benefits of `source()` over hardcoding:**
- Enables `dbt source freshness` checks
- Appears in the lineage graph
- Centralises source configuration in one YAML file
- Automatically applies database/schema from `_src_*.yml`

### `{{ ref('model_name') }}`

Used to reference **other dbt models** within the project. This is the core of dbt's DAG (Directed Acyclic Graph).

```sql
-- models/marts/finance/fct_orders.sql
with orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),
payments as (
    select * from {{ ref('stg_stripe__payments') }}
)
...
```

**Why `ref()` instead of hardcoding table names:**

| | Hardcoded | `ref()` |
|---|---|---|
| Dependency tracking | ❌ dbt can't see it | ✅ dbt builds the DAG |
| Execution order | ❌ Manual | ✅ Automatic |
| Environment switching | ❌ Must update SQL | ✅ Resolves automatically |
| Lineage graph | ❌ Not visible | ✅ Fully visible |

When you write `{{ ref('stg_jaffle_shop__orders') }}`, dbt:
1. Resolves the correct schema and database for your environment
2. Adds it as a dependency — ensuring it builds **before** the current model
3. Includes it in the lineage graph visible in `dbt docs serve`

---

## ⚙️ Snowflake vs PostgreSQL Differences

This project was originally designed for **Snowflake** but was adapted to run on **PostgreSQL**. Key differences encountered:

| Feature | Snowflake | PostgreSQL (this project) |
|---------|-----------|--------------------------|
| Database hierarchy | `database.schema.table` | Single database, multiple schemas |
| Compute layer | `CREATE WAREHOUSE` | Not needed — Postgres manages this |
| Loading from S3 | `COPY INTO ... FROM 's3://...'` | Manual CSV download + `\copy` |
| Column alias in `HAVING` | ✅ Allowed | ❌ Must repeat expression |
| Cross-database queries | ✅ Easy | ❌ Not supported |

**Example fix — `HAVING` clause:**
```sql
-- Snowflake ✅
having total_amount < 0

-- PostgreSQL ✅
having sum(amount) < 0
```

**Schema mapping:**
```
Snowflake: raw.jaffle_shop.customers
PostgreSQL: dbt_learn (db) → jaffle_shop (schema) → customers (table)
```

---

## 📖 Resources

- [dbt Fundamentals Course](https://learn.getdbt.com/) — Official dbt Learning platform
- [dbt Documentation](https://docs.getdbt.com/) — Full reference docs
- [dbt Community Slack](https://www.getdbt.com/community/) — 100k+ data professionals
- [dbt Best Practices](https://docs.getdbt.com/best-practices) — Official style guide
- [PostgreSQL Documentation](https://www.postgresql.org/docs/) — PostgreSQL reference

---

## 👤 About

Built by **Vinícius Caetano** as part of preparation for the **dbt Analytics Engineering Certification**.

This project demonstrates hands-on experience with dbt fundamentals including data modelling, testing, documentation, and source management using an open-source stack.