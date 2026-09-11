## Pull Requests

Read the [Staging and Production](https://github.com/PEAK-Incompetence/StopMotionHelper/discussions/7) overview to get up to speed with how we PR things.

### Coding conventions

Read the [design document](https://github.com/Winded/StopMotionHelper/blob/master/docs/DESIGN.md) to understand how to organize code and communicate between the server and client realms. Read the code to understand how variables and functions are named. In addition, use the following conventions:

- Use spaces instead of tabs for indentation.

> [!NOTE]
> The below note will be removed if we decide to use a formatter for this project. 

Since the codebase was originally developed without formatting assistance, make sure to disable your formatter if you use one. This avoids large diffs in your commits.

## User Documentation

We use the Github wiki to store tutorials for each feature of Stop Motion Helper.

The nature of Github wikis makes this one contributor-only.

## Developer Documentation

This project uses Sphinx and Sphinx Lua LS to generate documentation from LuaLS annotations. Developer documentation will live in a website. 

Because Sphinx Lua LS uses the Lua Language Server, it requires a `.luarc.json` file to configure it. As a hack, we use `.luarc.json` as our configuration for the documentation generator.

To get started with editing the documentation website, you may follow these steps:

1. Create a Python 3.13+ virtual environment 
    - If you use VSCode and have the Python and Python Environment extensions, you may use `Python: Create Environment` to create the virtual environment.
2. (If VSCode has installed the modules in `requirement.txt`, skip this step. Otherwise) run 

```
pip install -r requirements.txt
```
or if you use `uv`
```
uv pip install -r requirements.txt
```

3. `cd` to `docs` folder and run

```
make html
```

If done correctly, you should be able to open the `_build\html\index.html` file to preview your changes.