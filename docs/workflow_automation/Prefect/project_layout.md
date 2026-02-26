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

## 2. Avoid code duplication

### 2.1 Define "Atomic" Tasks
Keep tasks small and focused on a single responsibility. Instead of a task that "fetches data and sends a Slack alert," 
split it. This allows you to reuse the Slack alert task in 10 different pipelines without change.

```python
# src/my_package/tasks/notifications.py
from prefect import task

@task(retries=3)
def send_slack_alert(message: str, channel: str = "#data-alerts"):
    # Slack logic here
    print(f"Alerting {channel}: {message}")
```
### 2.2. Use "Flow Factories" for Pattern Repetition

If you have 50 pipelines that all do the same thing but for different tables, don't write 50 flow files. Write a function that returns a flow.

```python
# src/my_package/flows/factory.py
from prefect import flow
from my_package.tasks.ingestion import extract_table

def create_ingestion_flow(table_name: str):
    @flow(name=f"ingest-{table_name}")
    def table_flow():
        return extract_table(table_name)
    
    return table_flow

# Generate them dynamically
users_flow = create_ingestion_flow("users")
orders_flow = create_ingestion_flow("orders")
```

### 2.3 Prefer "Helper Functions" for Task Orchestration
If you have a group of tasks that always run together, wrap them in a plain Python function (not a task) that your flows can call.

Why? Prefect tasks shouldn't call other tasks directly (it loses visibility). A helper function allows the parent Flow to see and manage the individual task runs.

## 3. An example of pyproject.toml


```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "my-data-pipelines"
version = "0.1.0"
description = "Centralized Prefect tasks and data transformation flows"
readme = "README.md"
requires-python = ">=3.9"
authors = [
    { name = "Your Name", email = "your.email@example.com" }
]
# Define your core dependencies here
dependencies = [
    "prefect>=2.10.0",
    "pandas",
    "sqlalchemy",
    "psycopg2-binary", # or your preferred DB driver
    "python-dotenv"
]

[project.optional-dependencies]
dev = [
    "pytest",
    "ruff",         # Faster alternative to Flake8/Black
    "pre-commit"
]

[tool.setuptools.packages.find]
# This tells setuptools to look in the 'src' directory for your packages
where = ["src"]

[tool.ruff]
# Modern Python linting & formatting configuration
line-length = 88
select = ["E", "F", "I"] # Error, Pyflakes, Isort (imports)
```

### 3.1 The src Layout

By using where = ["src"], you follow the industry standard "src layout." This prevents Python from accidentally 
importing your project code unless it's properly installed, which catches many "it works on my machine but not in production" bugs.

### 3.2 optional-dependencies: 

I added a dev section. You can install your project plus development tools using pip install -e ".[dev]". This keeps your production environment lean.

### 3.3 ruff Integration: 
Prefect projects often involve many imports. I included a configuration for Ruff to keep your imports sorted and your code clean automatically.