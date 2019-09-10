# legion-airflow

An apache airflow plugin for the Legion Platform.

### How-To 

1. Start a Legion Cluster and authenticate using OAuth2. (Hit the cluster's base URL.) Copy the token to line 8 of ./dags/legion_dag.py
1. [Install, Start and InitDB for Airflow](https://airflow.apache.org/installation.html)  
1. Install the plugin defined in ./plugin/ to Airflow (or softlink/copy to $AIRFLOW_HOME/plugins)
1. Copy or import ./dags/legion_dag.py
1. Invoke

### DEV notes

1. We need a custom Airflow Connection - or maybe [this one](https://github.com/eliiza/airflow-oauth2) will work.
1. This plugin uses Poetry instead of Pip for dependency resolution **AND** depends upon a local build of legion-sdk. Both of these are because airflow has an irresolvable dependency issue with Jinja2. The workaround is to revert legion's sdk Pipfile to "jinja2==2.10.0" and update your localenv with the non-conflicting version. 
