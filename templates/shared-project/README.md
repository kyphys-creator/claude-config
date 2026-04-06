# Shared Project Templates

Skeleton files for bootstrapping a new shared-project layer (layer 3 in the four-layer architecture).

A **shared project** is a private repo that you collaborate on with a small team — e.g. an admin or coordination repo, a research collaboration, etc. Unlike your personal layer (layer 2, only you), a shared project has multiple humans editing it.

See [`docs/personal-layer.md`](../../docs/personal-layer.md) for the layer model and [`conventions/shared-repo.md`](../../conventions/shared-repo.md) for the operational rules.

## How to use

1. Create the new repo:
   ```bash
   mkdir -p ~/Claude/<your-shared-project>
   cd ~/Claude/<your-shared-project>
   git init
   ```

2. Copy templates:
   ```bash
   cp ~/Claude/claude-config/templates/shared-project/CLAUDE.md.template ./CLAUDE.md
   cp ~/Claude/claude-config/templates/shared-project/README.md.template ./README.md
   cp ~/Claude/claude-config/templates/shared-project/AUDIT.md.template ./AUDIT.md
   ```

3. Edit each file. **Important**: every reference to your personal layer or other private repos must be removed before sharing. Use the AUDIT.md checklist.

4. (Optional) Set up git-crypt with a shared key — see [`docs/git-crypt-guide.md`](../../docs/git-crypt-guide.md) and the "共有 git-crypt 鍵パターン" section in `conventions/shared-repo.md`.

5. Create the GitHub private repo and invite collaborators:
   ```bash
   gh repo create <owner>/<your-shared-project> --private --source=. --push
   gh api repos/<owner>/<your-shared-project>/collaborators/<collab> -X PUT
   ```

## Critical rules

- **Layer dependency**: shared projects can depend on `claude-config` (public, layer 1) only. NOT on your personal layer (`<your>-prefs/`, layer 2). See `conventions/shared-repo.md` for the rationale.
- **Audit before sharing**: Always run AUDIT.md before adding the first collaborator.
- **Standalone**: The repo's CLAUDE.md must work for someone who has no personal layer of their own.
