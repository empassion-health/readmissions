[![Apache License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) ![dbt logo and version](https://img.shields.io/static/v1?logo=dbt&label=dbt-version&message=1.x&color=orange)

# Readmissions 
This is Tuva Project's Readmissions data mart, which is a dbt project to create readmission measures.  It is based on the [CMS Readmission Measures Methodology](https://qualitynet.cms.gov/inpatient/measures/readmission/methodology) and includes other features, such as data quality checks specific to readmissions.

Check the latest [DAG](https://tuva-health.github.io/readmissions/#!/overview?g_v=1)

Knowledge Base:
- Check out the [methodology](https://thetuvaproject.com/docs/methodology/hospital-readmissions) used for the readmission data mart
- Check our the [data model](https://thetuvaproject.com/docs/data-models/data-marts/readmissions) for the readmissions data mart

Videos:
- [High-level overview](https://www.youtube.com/watch?v=TCG_QCb63n4) of what it looks like to do proper readmission analytics
- [How to video](https://www.youtube.com/watch?v=5pA-gm94PyU) explaining how to run the readmission data mart


## Pre-requisites
1. You have healthcare data (e.g. EHR, claims, lab, HIE, etc.) in a data warehouse.
2. You have run one of the Tuva Project's connectors or preprocessing projects ([claims_preprocessing_snowflake](https://github.com/tuva-health/claims_preprocessing_snowflake), [claims_preprocessing_redshift](https://github.com/tuva-health/claims_preprocessing_redshift), etc.) to transform your data. 
Alternatively, you can directly map your data to the source schema described in [source.yml](models/source.yml).
3. You have [dbt](https://www.getdbt.com/) installed and configured (i.e. connected to your data warehouse).

[Here](https://docs.getdbt.com/dbt-cli/installation) are instructions for installing dbt.

## Getting Started
Complete the following steps to configure the package to run in your environment.

1. [Clone](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository) this repo to your local machine or environment
2. Configure [dbt_project.yml](/dbt_project.yml)
    - Profile: set to 'tuva' by default - change this to an active profile in the profile.yml file that connects to your data warehouse 
    - Fill in vars (variables):
      - source_name - description of the dataset feeding this project 
      - input_database - database where sources feeding this project are stored 
      - input_schema - schema where sources feeding this project is stored 
      - output_database - database where output of this project should be written. We suggest using the Tuva database but any database will work. 
      - output_schema - name of the schema where output of this project should be written
3. Review [sources.yml](models/sources.yml). The table names listed are the same as in the Tuva data model (linked above).  If you decided to rename these tables:
    - Update table names in sources.yml
4. Execute `dbt build` to load seed files, run models, and perform tests.

## Usage Example
Sample dbt command specifying new variable names dynamically:

```
dbt build --vars '{input_database: my_database, input_schema: my_input, output_database: my_other_database, output_schema: i_love_data}'
```

## Contributions
Have an opinion on the mappings? Notice any bugs when installing and running the package? 
If so, we highly encourage and welcome contributions!

Join the conversation on [Slack](https://tuvahealth.slack.com/ssb/redirect#/shared-invite/email)!

## Database Support
This package has been tested on Snowflake and Redshift.
