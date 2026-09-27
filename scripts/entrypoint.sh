#!/bin/sh
# Point d'entrée CashQc.
# - Refuse --run tant que l'assistant (--setup) n'a pas été complété, pour que
#   l'agent ne démarre jamais sans la configuration durcie.
# - Réapplique config/durcissement.json à CHAQUE démarrage : si l'agent a
#   modifié son automaton.json, ses changements sont écrasés.
set -eu

CONFIG="$HOME/.automaton/automaton.json"

case " $* " in
  *" --run "*)
    if [ ! -f "$CONFIG" ]; then
      echo "[cashqc] Aucune configuration. Lance d'abord : docker compose run --rm automaton --setup" >&2
      exit 1
    fi
    ;;
esac

node /opt/cashqc/durcir-config.mjs

case " $* " in
  *" --setup "*|*" --configure "*|*" --pick-model "*)
    node /opt/automaton/dist/index.js "$@"
    node /opt/cashqc/durcir-config.mjs
    ;;
  *)
    exec node /opt/automaton/dist/index.js "$@"
    ;;
esac
