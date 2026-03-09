# Notes de stage - Laboratoire Numérique de l'ASP

Bienvenue sur le site de documentation des notes de stage prises au sein du
Laboratoire Numérique de l'ASP.

## Démarrage rapide

Ce projet utilise [MkDocs](https://www.mkdocs.org/) avec le thème
[Material](https://squidfunk.github.io/mkdocs-material/) pour générer un site de
documentation statique.

### Option 1 : Avec Nix (recommandé)

Un fichier `flake.nix` est prêt à l'emploi. Pour l'utiliser, vous avez besoin de
:

- Nix comme gestionnaire de paquets
- Les fonctionnalités expérimentales `nix-command` et `flakes` d'activées

Une fois Nix configuré, entrez dans le shell de développement :

```bash
nix develop
```

Cela installera automatiquement toutes les dépendances nécessaires (Python,
MkDocs, MkDocs Material, MkDocStrings).

Ensuite, lancez le serveur de développement :

```bash
mkdocs serve
```

Le site sera accessible à l'adresse `http://localhost:8000`.

### Option 2 : Installation manuelle des dépendances

Si vous n'utilisez pas Nix, vous devrez installer les dépendances suivantes :

- **Python 3.14**
- **mkdocs**
- **mkdocs-material**
- **mkdocstrings**

Via pip :

```bash
pip install mkdocs mkdocs-material mkdocstrings
```

Puis lancez le serveur :

```bash
mkdocs serve
```
