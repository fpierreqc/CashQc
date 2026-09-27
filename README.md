# CashQc

Configuration et déploiement **durcis** d'un
[automaton de Conway](https://github.com/Conway-Research/automaton) : un agent IA
autonome qui roule en continu, qui a son propre portefeuille crypto (USDC sur Base) et
qui paie son calcul avec des crédits Conway.

CashQc ne recopie pas le code d'automaton. Il :

1. **épingle** une version précise (`AUTOMATON_COMMIT`) ;
2. y applique des **correctifs de sécurité** (`patches/`) ;
3. le fait rouler dans un **conteneur Docker isolé**, sous un utilisateur sans
   privilèges, avec le code en lecture seule ;
4. **réimpose** une configuration prudente (`config/durcissement.json`) à chaque
   démarrage.

> ⚠️ **Lis [SECURITE.md](SECURITE.md) avant de mettre un seul dollar dans le
> portefeuille.** Même durci, l'agent peut lire sa propre clé privée avec son
> shell. Considère que **tout ce qui est dans le portefeuille peut être dépensé**.

## Prérequis

- Docker et Docker Compose
- Un portefeuille Ethereum à toi (adresse « créateur ») pour les droits d'audit
- Quelques dollars en USDC sur Base, **pas plus que ce que tu acceptes de perdre**

## Démarrage

```bash
cp .env.example .env          # ajuste les limites au besoin
mkdir -p data && sudo chown 10001:10001 data && sudo chmod 700 data   # uid de l'agent dans le conteneur
docker compose build

# 1. Assistant de configuration (interactif) : portefeuille, clé API Conway,
#    nom, prompt de genèse (voir config/genesis-prompt.exemple.md), adresse créateur.
docker compose run --rm automaton --setup

# 2. Vérifier l'état. La configuration durcie est déjà appliquée.
docker compose run --rm automaton --status

# 3. Envoyer un PETIT montant d'USDC (réseau Base) à l'adresse affichée.

# 4. Lancer l'agent
docker compose up
```

Arrêt : `Ctrl+C` ou `docker compose down`. L'état (portefeuille, base SQLite,
SOUL.md) reste dans `./data/`, et les fichiers de travail de l'agent restent dans le volume
Docker `travail` (`/root/travail`). Ailleurs, le système de fichiers est en lecture seule. **Sauvegarde `data/wallet.json` hors ligne** :
sans ce fichier, les fonds sont perdus.

## Ce qui est durci

| Élément | Automaton d'origine | CashQc |
|---|---|---|
| Réplication (`spawn_child`, `fund_child`) | activée, `maxChildren` ignoré (toujours 3) | outils retirés, et `maxChildren` réellement respecté (0) |
| Messages sociaux entrants | traités avec l'autorité « agent » | traités comme « externes » et le relais est coupé |
| Mise à jour de son propre code depuis GitHub | `pull_upstream`, `reset_to_upstream` | outils retirés, code en lecture seule dans l'image |
| Transferts de crédits | jusqu'à 50 $ par transfert, 250 $ par jour | outil retiré, plafonds à 0 |
| Paiements x402 | jusqu'à 1 $, domaine conway.tech | désactivés (liste de domaines vide) |
| Achat de crédits (`topup_credits`) | jusqu'à 2 500 $ par appel | plafond de 5 $ par appel (`AUTOMATON_MAX_TOPUP_USD`) |
| Exécution | shell sur l'hôte (root avec l'installateur `curl \| sh`) | conteneur non root, `cap_drop: ALL`, limites CPU, mémoire et processus |
| Configuration modifiée par l'agent | persiste | écrasée à chaque démarrage |

Pour changer une limite : modifie `.env` ou `config/durcissement.json`, puis relance
(`docker compose build` si tu as touché à `config/`).

## Mettre à jour automaton

1. Choisis un nouveau commit en amont et lis le diff.
2. Mets à jour `AUTOMATON_COMMIT`.
3. `docker compose build`. Si un correctif ne s'applique plus, la construction
   échoue : c'est voulu. Adapte alors le correctif.

## Structure

```
AUTOMATON_COMMIT              version épinglée d'automaton
patches/                      correctifs appliqués au moment du build
config/durcissement.json      configuration imposée à chaque démarrage
config/genesis-prompt.exemple.md
scripts/entrypoint.sh         point d'entrée du conteneur
scripts/durcir-config.mjs     fusion de la configuration durcie
Dockerfile, docker-compose.yml
SECURITE.md                   audit et risques résiduels
```
