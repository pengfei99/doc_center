# uv_tutorial

In this tutorial, we will learn:
- what is uv?
- how to install uv?
- how to use uv to manage a python project?

## 1. What is uv?

**UV** is a `python package and project manager` implemented with **Rust**. For package installation, uv is `10 to 100
times faster than pip`(not tested by me, so not sure).

Additionally, uv has the most of the functionality provided by tools like `pip, pip-tools, pipx, poetry, pyenv, twine, 
virtualenv, and more`. Therefore, uv is an `all-in-one solution`.

### Key uv features for managing your Python projects

- **Fast dependency installation**: Installs dependencies really fast, which is especially useful for large dependency trees.
- **Virtual environment management**: Automatically creates and manages virtual environments.
- **Python version management**: Allows the installation and management of multiple Python versions.
- **Project initialization**: Scaffolds a full Python project, including the root directory, Git repository, virtual environment, pyproject.toml, README, and more.
- **Dependency management**: Installs, updates, removes, and locks direct and transitive dependencies, which allows for environment reproducibility.
- **Package builds and publication management**: Allows you to build and publish packages to package repositories like the Python Package Index (PyPI).
- **Developer tooling support**: Installs and lets you run development tools, such as pytest, Black, and Ruff.


`uv is a standalone binary` that allows for a smooth installation and quick upgrades. 

> You don’t need to have Python installed on your system to install uv.

## 2. Install uv 

Based on your OS, the installation guide is different. You can find the official doc [here](https://github.com/astral-sh/uv)


### Linux/MacOS installation

Under Linux, it's quite simple. Just use the provided installation script.


```bash
curl -LsSf https://astral.sh/uv/install.sh | sh

# you may need to restart your shell

# check uv version
uv --version

```

### Windows installation

## 3. Use uv to create a python project skeleton

Go to the root folder where you want to put your project. Then run the below commands

```bash
# create a project
uv init my-app

# goto the project folder
cd my-app

# check the generated files
> tree -L 3 -a .
.
├── main.py
├── pyproject.toml
├── .python-version
└── README.md

1 directory, 4 files
```

You should see the below files

- **pyproject.toml**: The new standard for defining dependencies (replaces requirements.txt).
- **.python-version**: Locks the Python version for this specific project.
- **main.py**: A simple "Hello World" entry point.
- **README.md**: Read me of your project

### 3.1 Add uv support to an existing project

If you want to start managing an existing project with uv, then navigate to the project directory and run the following command

```bash
uv init
```

This command will create the uv project structure for you. If your project already have `main.py`, `README.md`, etc. 
It won’t overwrite them. It will not modify your Git repository.

> However, this command **won’t work** if you already have a `pyproject.toml` file in place.
> Quick fix: you can move the `pyproject.toml` file to another location and run the `uv init` command. 
> Then merge the new `pyproject.toml` file with any relevant configuration from your old `pyproject.toml`.

### 3.1 Set up python virtual environment

In modern `uv workflows`, you often don't need to manually create the `virtual environment`. If you are inside a 
`project folder (with a pyproject.toml)`, simply running the below commands will automatically create the default 
**.venv** folder, if it doesn't exist:

```bash
# Creates the venv and installs all dependencies from the lockfile.
uv sync

# Creates a temporary or project-local venv just to run that script, then cleans up (or keeps it cached).
uv run main.py

# Set a specific Python version for your project
uv python pin 3.14
```

#### 3.1.1 Create a virtual environment explicitly

I still prefer the old school way to make everything clear.

```bash
# create a venv with specific name and python version
uv venv my_venv --python 3.13

# this will create a folder with the name my_venv.

# to activate the virtual env
# linux
source .venv/bin/activate

# windows
.venv/Scripts/activate 


# to deactivate
deactivate
```

> If you don't specifier a name for your venv, the folder name will be .venv
> It's better for uv to locate the virtual env, if uv can't find one, when you run `uv run main.py`, uv will
> create a new .venv

### 3.2 Install the dependencies

You need to activate the `right virtual env` before you install the dependencies. 

```bash
# add packages to your project
uv add notebook

# upgrade existing packages
uv add --upgrade notebook

# add dev packages to your project
uv add --dev ruff pytest 

# if you have a requirements.txt, you can add all dependencies
uv add -r requirements.txt

# to remove a packages
uv remove notebook

# if you modify your pyproject.toml to update dependencies, you need to update lockfile to get new dependencies
uv sync

# if you don't want any update of your project, you can lock the dependencies
uv lock

# to view all existing packages in your venv
uv pip list
```

## 4. Run your project

Once you’ve created the project, you can use `uv` to run the entry-point script `main.py` file by default. 

```bash
$ uv run main.py

Using CPython 3.13.2
Creating virtual environment at: .venv
Hello from my-app!
```

The first time you run the `uv run` command, it’ll display the Python version you’re currently using for the project. 
It’ll also inform you that uv has created a dedicated Python virtual environment for the project. 
The final output line shows the message that results from calling the main() function defined in main.py.


Now update your `main.py` with the below code, and rerun `uv run main.py`

```python
import numpy as np
import pandas as pd

def main():
    print("Hello from my-app!")
    gen_df()

def gen_df():
    data = np.array([['', 'Col1', 'Col2'],
                     ['Row1', 1, 2],
                     ['Row2', 3, 4]])

    print(pd.DataFrame(data=data[1:, 1:],
                       index=data[1:, 0],
                       columns=data[0, 1:]))


if __name__ == "__main__":
    main()
```

You should see something like

```bash
File "/home/pliu/Documents/git/uv_tutorial/my-app/main.py", line 1, in <module>
    import numpy as np
ModuleNotFoundError: No module named 'numpy'
```

Add pandas to your project, and rerun `uv run main.py`

```bash
uv add pandas

uv run main.py
# output example
Hello from my-app!
     Col1 Col2
Row1    1    2
Row2    3    4
```

> Now you will ask I did not install numpy, why numpy is in my project dependencies?

That's because you have two types of dependencies:
- `Direct dependencies`: Packages that your project depends on directly. For example, pandas.
- `Transitive dependencies`: Packages that support your project’s direct dependencies. For example, the pandas library 
              depends on numpy, and uv installed as a transitive dependency.

In `pyproject.toml` file, you will only see the `Direct dependencies`. Internally, `uv` uses the `uv.lock` file to
track `Direct dependencies` and `Transitive dependencies`.

## 5. Build packages

Now, imagine your project is ready to release. You can also use `uv to build and publish` the project to a 
`package repository like PyPI`. 

### 5.1 Configuring the Project

Your app has a `command-line interface (CLI)`, so you need to explicitly set the project’s `entry-point script` so that 
the build system can properly set up the executable file for the app. 


Go to the `pyproject.toml` file and add the following:


```toml
# specify the package entry point
[project.scripts]
my-app = "main:main"

# specifies that the build system will require setuptools and wheel.
[build-system]
requires = ["setuptools>=78.1.0", "wheel>=0.45.1"]
build-backend = "setuptools.build_meta"
```

You can use the `uv build` command to build source and binary distributions for your project. 

> By default, `uv build` will build the project and place the distributions in a `dist/` subdirectory under the project’s root.

```bash
# build the source distribution
uv build --sdist
# build the binary distribution
uv build --wheel

# without any flag, it will build both
uv build
```

## 6. Publish your package

The final step is to publish the built package to a `package repository` like PyPI so that your users can download 
and install it on their systems.

Before publishing a package to PyPI, you should make sure that everything works correctly. 
To this end, you can publish your package to the TestPyPI index, which is a special repository designed for testing 
purposes. You’ll need to set up an account in TestPyPI and generate an API token. Once you’ve done that, you can 
manually edit your pyproject.toml file as shown below:

```toml
[[tool.uv.index]]
name = "testpypi"
url = "https://test.pypi.org/simple/"
publish-url = "https://test.pypi.org/legacy/"
explicit = true
```

```bash
# to publish the package
$ uv publish --index testpypi --token your_token_here
```

To test your package

```bash
uv venv test_venv

source test_venv/bin/activate

uv pip install -i https://test.pypi.org/simple/ my-app

uv run my-app
```