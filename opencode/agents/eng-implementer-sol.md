---
description: Global implementation worker on GPT-6.2 Sol (`delegate start --typist sol`). Implements a written spec inside one git worktree, dispatched and reviewed by Claude Code (engineering-orchestrator skill). Same permissions as eng-implementer; keep the two lists identical. Hard denies for pushes, history rewrites, deploys, publishing, network fetches, secrets and anything outside the worktree.
mode: primary
model: openai/gpt-6.2-sol#high
permissions:
  # Stay inside the worktree; /tmp is the only outside location.
  - { action: external_directory, resource: "*", effect: deny }
  - { action: external_directory, resource: "/tmp/*", effect: allow }
  # Secrets.
  - { action: read, resource: "*.env", effect: deny }
  - { action: read, resource: "*.env.*", effect: deny }
  - { action: read, resource: "*.env.example", effect: allow }
  - { action: read, resource: "*.pem", effect: deny }
  - { action: read, resource: "*id_rsa*", effect: deny }
  - { action: read, resource: "*id_ed25519*", effect: deny }
  - { action: shell, resource: "env", effect: deny }
  - { action: shell, resource: "printenv*", effect: deny }
  - { action: shell, resource: "*LITHOSAI*", effect: deny }
  - { action: shell, resource: "*_API_KEY*", effect: deny }
  - { action: shell, resource: "*.ssh/*", effect: deny }
  - { action: shell, resource: "*.config/opencode*", effect: deny }
  - { action: shell, resource: "*.local/share/opencode*", effect: deny }
  - { action: shell, resource: "*.claude/*", effect: deny }
  - { action: shell, resource: "*.codex/*", effect: deny }
  - { action: shell, resource: "*.config/gcloud*", effect: deny }
  - { action: shell, resource: "*.aws/*", effect: deny }
  - { action: shell, resource: "*.gnupg*", effect: deny }
  # Unattended run: no questions, no subagents, no web.
  - { action: question, resource: "*", effect: deny }
  - { action: subagent, resource: "*", effect: deny }
  - { action: webfetch, resource: "*", effect: deny }
  - { action: websearch, resource: "*", effect: deny }
  - { action: shell, resource: "curl*", effect: deny }
  - { action: shell, resource: "wget*", effect: deny }
  - { action: shell, resource: "ssh*", effect: deny }
  - { action: shell, resource: "scp*", effect: deny }
  - { action: shell, resource: "rsync*", effect: deny }
  # Git: the worker edits and may commit on its task branch; the orchestrator owns everything else.
  - { action: shell, resource: "git push*", effect: deny }
  - { action: shell, resource: "git pull*", effect: deny }
  - { action: shell, resource: "git fetch*", effect: deny }
  - { action: shell, resource: "git stash*", effect: deny }
  - { action: shell, resource: "git rebase*", effect: deny }
  - { action: shell, resource: "git merge*", effect: deny }
  - { action: shell, resource: "git reset*", effect: deny }
  - { action: shell, resource: "git clean*", effect: deny }
  - { action: shell, resource: "git checkout*", effect: deny }
  - { action: shell, resource: "git switch*", effect: deny }
  - { action: shell, resource: "git restore*", effect: deny }
  - { action: shell, resource: "git branch*", effect: deny }
  - { action: shell, resource: "git branch --show-current*", effect: allow }
  - { action: shell, resource: "git worktree*", effect: deny }
  - { action: shell, resource: "git config*", effect: deny }
  - { action: shell, resource: "git tag*", effect: deny }
  - { action: shell, resource: "git remote*", effect: deny }
  - { action: shell, resource: "gh *", effect: deny }
  # Destructive and privileged commands.
  - { action: shell, resource: "rm -rf*", effect: deny }
  - { action: shell, resource: "rm -fr*", effect: deny }
  - { action: shell, resource: "rm -r *", effect: deny }
  - { action: shell, resource: "rm -R *", effect: deny }
  - { action: shell, resource: "sudo*", effect: deny }
  - { action: shell, resource: "su *", effect: deny }
  - { action: shell, resource: "pkill*", effect: deny }
  - { action: shell, resource: "killall*", effect: deny }
  - { action: shell, resource: "systemctl*", effect: deny }
  - { action: shell, resource: "shutdown*", effect: deny }
  - { action: shell, resource: "reboot*", effect: deny }
  - { action: shell, resource: "pacman*", effect: deny }
  - { action: shell, resource: "yay*", effect: deny }
  # Production: deploys, publishing, cloud and cluster control.
  - { action: shell, resource: "*deploy*", effect: deny }
  - { action: shell, resource: "gcloud*", effect: deny }
  - { action: shell, resource: "aws *", effect: deny }
  - { action: shell, resource: "az *", effect: deny }
  - { action: shell, resource: "kubectl*", effect: deny }
  - { action: shell, resource: "helm *", effect: deny }
  - { action: shell, resource: "terraform*", effect: deny }
  - { action: shell, resource: "netlify*", effect: deny }
  - { action: shell, resource: "vercel*", effect: deny }
  - { action: shell, resource: "flyctl*", effect: deny }
  - { action: shell, resource: "docker push*", effect: deny }
  - { action: shell, resource: "npm publish*", effect: deny }
  - { action: shell, resource: "pnpm publish*", effect: deny }
  - { action: shell, resource: "yarn publish*", effect: deny }
  - { action: shell, resource: "cargo publish*", effect: deny }
  - { action: shell, resource: "twine upload*", effect: deny }
---
