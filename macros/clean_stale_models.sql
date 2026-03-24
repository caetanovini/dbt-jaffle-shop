{%- macro clean_stale_models(schema=target.schema, days=7, dry_run=True) -%}

    {% set get_drop_commands_query %}
        select
            'DROP TABLE ' || schemaname || '.' || relname || ';'
        from pg_stat_user_tables
        where schemaname = '{{ schema }}'
        and last_autovacuum <= current_date - interval '{{ days }} days'
        and last_autovacuum is not null

        union all

        select
            'DROP VIEW ' || table_schema || '.' || table_name || ';'
        from information_schema.views
        where table_schema = '{{ schema }}'

    {% endset %}

    {{ log('\nGenerating cleanup queries...\n', info=True) }}
    {% set drop_queries = run_query(get_drop_commands_query).columns[0].values() %}

    {% for query in drop_queries %}
        {% if dry_run %}
            {{ log(query, info=True) }}
        {% else %}
            {{ log('Dropping object with command: ' ~ query, info=True) }}
            {% do run_query(query) %}
        {% endif %}
    {% endfor %}

{% endmacro %}