# Environment Secrets stay out of the agent's context

`apta-investigate` keeps each Environment's connection details in a gitignored `.apta-investigate/` folder at the project root, not inside the installed skill folder. Installs, reinstalls and uninstalls (`install.sh --force`, `--uninstall`, plugin updates) replace or delete the skill folder, and one project can have the skill installed for several agents at once. Inside that folder, Environment Settings (`environments/<env>.env`) are split from Environment Secrets (`secrets/<env>.env`). The agent may read and edit the settings, so it can fill them in from the codebase. Only the skill's scripts read the secrets, and they pass them to `psql`/`logcli` through the child process's environment, never through command-line arguments or output.

## Consequences

- This is a guardrail against accidental leaks, not a security boundary. The agent runs as the same OS user as the scripts, so a deliberately misbehaving agent could still read `secrets/`. The guardrail has three layers:
  - skill instructions,
  - a Claude Code plugin hook, or a `Read(./.apta-investigate/secrets/**)` deny rule when the skill is installed without the plugin,
  - scripts that mask secret values in their error output.

  Codex has no equivalent hook, so there it rests on instructions and the scripts. A hard boundary would need a separate OS user or a background process that holds the secrets. We rejected that for v1 as too heavy for a laptop tool.
- Secrets are stored as plain values, not as references to Infisical, so the skill works without Infisical access. Infisical references could be added later without changing the folder layout.
