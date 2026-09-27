# Proxy de sortie CashQc (Squid) : liste blanche de domaines, HTTPS seulement.
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends squid \
 && rm -rf /var/lib/apt/lists/*

COPY squid.conf /etc/squid/squid.conf
COPY domaines-autorises.txt /etc/squid/domaines-autorises.txt
RUN squid -k parse -f /etc/squid/squid.conf

# Squid roule directement sous l'utilisateur « proxy », jamais en root.
USER proxy
EXPOSE 3128
ENTRYPOINT ["squid", "-N", "-f", "/etc/squid/squid.conf"]
