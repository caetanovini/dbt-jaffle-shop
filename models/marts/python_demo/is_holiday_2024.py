import holidays
import pandas as pd

def model(dbt, session):

    dbt.config(
        materialized='table',
        packages=['pandas', 'holidays']
    )

    # Load the date_spine model as a dataframe
    date_spine_df = dbt.ref('date_spine')

    # Convert to pandas if on Snowflake (Snowpark returns Snowpark df)
    df = date_spine_df.to_pandas()

    # Check each date against US holidays
    us_holidays = holidays.US()
    df['IS_HOLIDAY'] = df['DATE_DAY'].apply(
        lambda date: date in us_holidays
    )

    return df