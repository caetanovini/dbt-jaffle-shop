{% macro grant_select(schema_name=target.schema, user_name=target.user) %}

    {% set sql_query %}
        grant usage on schema {{ schema_name }} to {{ user_name }};
        grant select on all tables in schema {{ schema_name }} to {{ user_name }};
    {% endset %}

    {{ log('Granting select on all tables and views in schema ' ~ schema_name ~ ' to user ' ~ user_name, info=True) }}
    {% do run_query(sql_query) %}
    {{ log('Privileges granted', info=True) }}

{% endmacro %}