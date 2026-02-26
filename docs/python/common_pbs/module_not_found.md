# ModuleNotFoundError. 

I think every python developer has this error once in their life. Imagine the below python project architecture

```text
my_project/
├── pk1/
│   └── exp2.py
└── pk2/
    └── exp1.py
```

In `pk2/exp1.py`, you call `from pk1.exp2 import function1`. When you run `python pk2/exp1.py` directly, you will receive
the `pk1 ModuleNotFoundError`. You’re hitting this because Python doesn't automatically know that `the parent directory of your packages`
should be on its "search list" (the sys.path).

When you run `python pk2/exp1.py` directly, `Python sets the current directory to pk2`. It looks around, sees no pk1 inside pk2, and gives up.


To fix this problem, you need to transform your python scripts into a python project. 
- pyproject.toml: The modern way to define your python project
- __init__.py: it tells python interpreter this folder is a python package

```text
my_project/
├── pyproject.toml      # The modern way to define your project
├── pk1/
│   ├── __init__.py
│   └── exp2.py
└── pk2/
    ├── __init__.py
    └── exp1.py
```

The toml file can be really simple. Below is a minimum example

```toml
[build-system]
requires = ["setuptools", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "my_project"
version = "0.1.0"
```

Add your python project to the python environment with the below command

```shell
# go to your project root folder
cd /path/to/my_project

# add your project to your python env
# The -e (editable) flag tells Python to link your project folder into your environment's site-packages dynamically.
pip install -e .


```

> after the above commands, all functions in your my_project will work from anywhere on your machine while you're in that virtual environment.