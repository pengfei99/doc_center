# Prefect project layout

To avoid duplicating code in a growing Prefect project, you should treat your workflow as a proper Python package 
rather than just a collection of independent scripts.

The industry standard is to separate Orchestration (Flows) from Logic (Tasks/Utils).

## 1. Recommended Project Structure

Organizing your project this way ensures that your shared tasks are importable from any flow, whether you are running them locally or in a remote worker.

```text
my-data-project/
├── pyproject.toml      # Project metadata & dependencies
├── src/
│   └── my_package/
│       ├── __init__.py
│       ├── common/     # Shared logic (not necessarily tasks)
│       │   ├── __init__.py
│       │   └── db_utils.py
│       ├── tasks/      # Reusable @task decorated functions
│       │   ├── __init__.py
│       │   └── notifications.py
│       └── flows/      # Your main workflow entry points
│           ├── __init__.py
│           ├── ingestion_flow.py
│           └── transform_flow.py
├── tests/
└── prefect.yaml        # Deployment configuration
```