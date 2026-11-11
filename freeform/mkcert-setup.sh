# Trusted HTTPS for DDEV projects inside the workspace, so curl and agents
# can reach https://... without certificate errors. Runs every start, after
# Docker is up and `ddev utility download-images` has pulled ddev-utilities.
#
# 1. `mkcert -install` creates the CA in ~/.local/share/mkcert (persistent
#    home) on first run and adds it to the system trust store, which lives in
#    the container layer and so is lost on every restart.
# 2. Copy that CA into the ddev-global-cache volume at mkcert/, where
#    ddev-webserver's start.sh looks for it when it makes the site's
#    certificate. DDEV does this copy itself only when ddev-router is enabled;
#    drupal-core and drupal-contrib omit the router, so without this the web
#    container makes its own CA that nothing trusts. The web container makes a
#    new certificate each time it starts, and every template runs
#    `ddev poweroff` at shutdown, so the next `ddev start` picks the CA up.
mkcert -install 2> /dev/null || true
MKCERT_CAROOT="$(mkcert -CAROOT 2> /dev/null)"
if [ -r "$MKCERT_CAROOT/rootCA.pem" ] && [ -r "$MKCERT_CAROOT/rootCA-key.pem" ]; then
  if docker run --rm --user 0 \
    -v ddev-global-cache:/mnt/ddev-global-cache \
    -v "$MKCERT_CAROOT":/mnt/caroot:ro \
    ddev/ddev-utilities sh -c "mkdir -p /mnt/ddev-global-cache/mkcert && cp -p /mnt/caroot/rootCA.pem /mnt/caroot/rootCA-key.pem /mnt/ddev-global-cache/mkcert/ && chown -R $(id -u):$(id -g) /mnt/ddev-global-cache/mkcert" > /dev/null 2>&1; then
    echo "✓ mkcert CA trusted and copied into ddev-global-cache"
  else
    echo "⚠ Could not copy the mkcert CA into ddev-global-cache; HTTPS inside the workspace will not be trusted"
  fi
else
  echo "⚠ mkcert CA not found at $MKCERT_CAROOT; HTTPS inside the workspace will not be trusted"
fi
