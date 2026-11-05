# Reproducing the environment
The adjacent exact-version requirements were frozen from the environment that ran the experiments. Use `uv venv --python 3.12 qec/.venv` then `uv pip install --python qec/.venv/bin/python -r qec/requirements.txt`. System Python lacked ensurepip; uv successfully provisioned CPython 3.12.13. The environment itself is ignored.
