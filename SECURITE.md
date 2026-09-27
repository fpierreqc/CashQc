# Sécurité : audit d'automaton et risques résiduels

Revue statique d'automaton au commit `d8f8168` (voir `AUTOMATON_COMMIT`).
Les chemins sont relatifs au dépôt automaton. **Rien de ceci n'a été testé contre
un agent réel avec de vrais fonds.**

## En résumé

Les protections d'automaton (listes de commandes interdites, fichiers protégés,
plafonds de dépenses) s'appliquent **au niveau des outils**, pas au niveau du
système. L'agent a un outil `exec` qui lance n'importe quelle commande shell, et
presque tout peut se contourner par là. CashQc réduit les dégâts possibles, mais ne
change pas cette réalité. **L'agent peut lire sa clé privée et dépenser tout le
contenu du portefeuille.**

## Constats

### Critiques

| # | Constat | Preuve | CashQc |
|---|---|---|---|
| C1 | L'agent peut lire `~/.automaton/wallet.json` (clé privée en clair) avec son shell. Le seul garde-fou est la regex `cat\s+.*wallet\.json`, qu'on contourne avec `head`, `base64` ou `node -e`. | `src/identity/wallet.ts`, `src/agent/policy-rules/command-safety.ts:221` | **Non corrigé** (inhérent). On limite l'impact en mettant peu de fonds. |
| C2 | Hors sandbox Conway, `exec` roule directement sur l'hôte. L'installateur `curl \| sh` le fait rouler en root. | `src/conway/client.ts:106-118`, `scripts/automaton.sh` | Conteneur non root, `cap_drop: ALL`, système de fichiers en lecture seule. |
| C3 | Les plafonds de dépenses ne couvrent que `transfer_credits`. `topup_credits` peut dépenser jusqu'à 2 500 $ par appel. Les paiements x402 sont comptés à 0 ¢. `fund_child` n'a aucun plafond réel. | `src/conway/topup.ts:24,50`, `src/agent/policy-rules/financial.ts:190-207` | Plafond `AUTOMATON_MAX_TOPUP_USD` (5 $ par défaut), x402 désactivé, `fund_child` et `transfer_credits` retirés. |
| C4 | Les messages sociaux entrants reçoivent l'autorité « agent ». N'importe qui peut donc déclencher la réplication, le financement ou l'automodification. Leur signature n'est pas vérifiée. | `src/agent/loop.ts:424`, `src/agent/policy-engine.ts:129` | Correctif : source `"social"`, donc traitée comme externe. De plus, le relais est coupé (`socialRelayUrl` invalide). |

### Élevés

| # | Constat | CashQc |
|---|---|---|
| H1 | Les fichiers protégés ne couvrent pas `financial.ts`, `command-safety.ts`, `authority.ts`, `x402.ts` ni `topup.ts`. Via le shell, aucune protection réelle (`cp`, `tee`, `perl -i`…). | Le code dans `/opt/automaton` appartient à root : l'agent ne peut pas le modifier. |
| H2 | Le filtre de commandes est une liste noire de regex, qu'on contourne avec base64, des variables, `sh -c`, etc. | **Non corrigé.** Le conteneur est la vraie barrière. |
| H3 | `pull_upstream` et `reset_to_upstream` tirent et compilent du code depuis GitHub. `reset_to_upstream` exécute les scripts npm. Les enfants clonent la branche `main` sans épinglage. | Outils retirés. Version épinglée et construite dans l'image. |
| H4 | `maxChildren` est ignoré : la limite est toujours 3. | Correctif : la valeur de la config est passée à `spawnChild`. De plus, `spawn_child` est retiré. |

### Moyens

- **M1. Conway a beaucoup de contrôle.** Conway voit toute l'inférence qui passe par lui, héberge les sandbox (et peut donc lire la clé s'il y en a une), exploite le relais social et fixe le montant des paiements x402 de recharge.
- **M2.** `maxInferenceDailyCents` ne s'applique qu'aux outils `chat` et `inference`. **Il ne plafonne pas l'inférence de la boucle principale** (`src/agent/policy-rules/financial.ts:248`). Le vrai plafond, c'est le solde de crédits Conway et le plafond de recharge.
- **M3.** Les clés OpenAI et Anthropic mises dans la config ou dans `.env` peuvent être lues par l'agent.

## Risques qui restent avec CashQc

1. **La clé du portefeuille est accessible à l'agent.** Il pourrait signer une transaction USDC vers n'importe quelle adresse avec un script `node`, sans passer par un seul outil surveillé. → Ne mets jamais plus que ce que tu acceptes de perdre.
2. **Le réseau n'est pas filtré.** L'agent peut joindre n'importe quel hôte. Pour aller plus loin, mets un proxy sortant avec une liste blanche (api.conway.tech, inference.conway.tech, ton RPC Base).
3. **Les correctifs se trouvent dans le code que l'agent exécute.** Il ne peut pas les modifier dans l'image, mais un processus lancé par `exec` pourrait réimplémenter un outil retiré en appelant directement l'API Conway avec la clé API, qu'il peut lire.
4. **Les enfants déjà créés** (si tu as roulé automaton sans CashQc) ne sont pas touchés.

## Recommandations d'exploitation

- Portefeuille neuf, dédié, avec **5 à 25 $ USDC** au maximum.
- Surveille l'adresse du portefeuille avec une alerte externe (par exemple un explorateur Base ou une alerte de portefeuille).
- Lis `data/SOUL.md` et les journaux (`docker compose logs`) régulièrement.
- Ne réutilise pas de clés API qui servent ailleurs. Mets un plafond de dépenses chez le fournisseur.
- Garde `restart: "no"` : un humain regarde avant chaque relance.
