# Common problems in conda


## conda init powershell/cmd.exe

To enable conda in `powershell` and `cmd`, you can use the command `conda init`. For example

```powershell
conda init powershell
conda init cmd.exe
```


**But this command had very bad side effects.**

Because it adds conda to your powershell or cmd by adding environment variables such as:
- CONDA_EXE="C:\ProgramData\Miniconda3-py311\Scripts\conda.exe"
- CONDA_PYTHON_EXE="C:\ProgramData\Miniconda3-py311\python.exe"

If you only have one python version, this will not cause problems, but if you have multiple python versions(e.g. py313)
the conda env for python 3.13 will never work, because these two lines will overwrite any conda env set for py313.

To `reverse` the `conda init` command:

```powershell
conda init --reverse powershell
conda init --reverse cmd.exe
```

These two commands will remove all the `@SET CONDA_EXE`, `@SET CONDA_PYTHON_EXE`

