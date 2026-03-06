# AI-assistent instructies — dreejt/mintis-sync

Dit bestand wordt automatisch gelezen door GitHub Copilot en andere AI-assistenten.

## Wat is dit project?

`dreejt/mintis-sync` is een Composer-pakket met een bash-script (`sync.sh`) voor het synchroniseren van Bedrock-based WordPress omgevingen (development ↔ staging ↔ production). Het wordt geïnstalleerd als Composer-dependency in WordPress-projecten.

## Projectstructuur

```
sync.sh              # Hoofd sync-script (bash)
setup-wp-cli.php     # Genereert wp-cli.yml vanuit .env
composer.json        # Composer pakket definitie (geen "version" veld — dat regelt de git tag)
CHANGELOG.md         # Versiegeschiedenis — de bovenste versie bepaalt de release-tag
.sync.example        # Voorbeeld config voor projecten die dit pakket gebruiken
install.sh           # Installatie helper voor handmatige installatie
```

## Release workflow

**Versienummer staat in CHANGELOG.md, niet in composer.json of sync.sh.**

1. `CHANGELOG.md` bovenaan bijwerken met nieuw versieblok — **dit doet de AI-assistent automatisch, de gebruiker hoeft dit niet zelf te doen**
2. Commit en push naar `main`
3. De GitHub Action (`.github/workflows/release.yml`) leest de bovenste versie uit `CHANGELOG.md` en maakt automatisch een git tag aan als die nog niet bestaat
4. Packagist pikt de tag op en maakt de versie beschikbaar via `composer update dreejt/mintis-sync`

**Nooit** handmatig `SCRIPT_VERSION` in `sync.sh` aanpassen — dat wordt automatisch gelezen uit `vendor/composer/installed.json` in het project dat het pakket gebruikt.

## Instructies voor AI-assistent

- **Wijzig je `sync.sh` of andere bestanden? Update dan altijd automatisch `CHANGELOG.md`** met een nieuw versieblok bovenaan. Verhoog het patch-nummer (bijv. 1.5.2 → 1.5.3) tenzij de wijziging groter is.
- De gebruiker hoeft `CHANGELOG.md` nooit zelf aan te passen.
- Formaat versieblok:
  ```
  ## [x.y.z] - YYYY-MM-DD

  ### Added / Changed / Fixed
  - Omschrijving van de wijziging
  ```
- Na het aanpassen van `CHANGELOG.md`: meld kort aan de gebruiker dat de changelog is bijgewerkt en wat de nieuwe versie is.

## Conventies

- Bash-script: gebruik `success()`, `error()`, `warning()`, `info()` voor output (nooit `echo` direct)
- Kleuren via variabelen: `$GREEN`, `$RED`, `$YELLOW`, `$BLUE`, `$NC`, `$BOLD`, `$NORMAL`
- Altijd `set -eo pipefail` bovenaan het script
- Foutmeldingen gaan naar stderr (`>&2`), status naar stdout
- Nederlandse README/comments zijn OK, Engelstalige CHANGELOG

## Afhankelijkheden (lokaal + remote)

- WP-CLI (lokaal én op remote server)
- rsync
- SSH-toegang tot servers
- PHP ≥ 8.1 (alleen voor setup-wp-cli.php)
