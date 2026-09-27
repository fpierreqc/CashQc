# CashQc — image isolée pour faire rouler un automaton durci.
FROM node:22.22-bookworm-slim AS build

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

ARG AUTOMATON_REPO=https://github.com/Conway-Research/automaton.git
COPY AUTOMATON_COMMIT /tmp/AUTOMATON_COMMIT
COPY patches /tmp/patches

WORKDIR /opt/automaton
RUN COMMIT="$(cat /tmp/AUTOMATON_COMMIT)" \
 && git init -q . \
 && git remote add origin "$AUTOMATON_REPO" \
 && git fetch -q --depth 1 origin "$COMMIT" \
 && git checkout -q FETCH_HEAD \
 && for p in /tmp/patches/*.patch; do git apply --verbose "$p"; done \
 && corepack enable \
 && pnpm install --frozen-lockfile \
 && pnpm run build \
 && rm -rf .git

# Node >= 22.21 requis pour NODE_USE_ENV_PROXY (passage par le proxy).
FROM node:22.22-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --uid 10001 --home-dir /root --no-create-home agent \
 && chown agent:agent /root && chmod 0700 /root

# Le code appartient à root : l'agent (uid 10001) ne peut pas réécrire
# son moteur, ses règles de politique ni sa constitution.
COPY --from=build /opt/automaton /opt/automaton
COPY config/durcissement.json /opt/cashqc/durcissement.json
COPY scripts/durcir-config.mjs scripts/entrypoint.sh /opt/cashqc/
RUN chmod 0755 /opt/cashqc/entrypoint.sh

# Utilisateur non root, mais avec /root comme dossier personnel : l'outil
# write_file d'automaton n'accepte que des chemins sous /root.
USER agent
ENV HOME=/root
WORKDIR /root
VOLUME ["/root/.automaton"]

ENTRYPOINT ["/opt/cashqc/entrypoint.sh"]
CMD ["--run"]
