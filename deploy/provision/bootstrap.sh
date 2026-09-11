#!/usr/bin/env bash
# =============================================================================
# AECP provision/bootstrap: deploy the 100% Apache Enterprise Computing Platform
# onto a bare Ubuntu host (works identically on AWS/Azure/GCP/Oracle Ubuntu
# images). No Docker anywhere - direct systemd/cgroup management only.
#
# Idempotent: safe to re-run; completed steps skip via markers.
# Fail-fast: set -euo pipefail; every Apache download is sha512-verified.
#
# Usage:  sudo bash bootstrap.sh [--skip-start]
# Env:    AECP_SKIP_APT=1, AECP_SKIP_START=1, AECP_JAVA_HOME, AECP_DATA, ...
# =============================================================================
set -euo pipefail

# ------------------------------------------------------------------ config
AECP_ROOT="${AECP_ROOT:-/opt/aecp}"
APPS="$AECP_ROOT/apps"
DATA_ROOT="${AECP_DATA:-/var/lib/aecp}"
VENV="${AECP_VENV:-$AECP_ROOT/venv}"
BIN="$AECP_ROOT/bin"
DL="$APPS/downloads"
AECP_USER="${AECP_USER:-aecp}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ "${AECP_FROM_REPO:-1}" = "1" ] && [ -f "$REPO_ROOT/pyproject.toml" ]; then
  REPO="$REPO_ROOT"
else
  REPO="${AECP_REPO:-$AECP_ROOT/aecp-repo}"
  AECP_REPO_URL="${AECP_REPO_URL:-https://github.com/nrupala/aecp.git}"
  if [ ! -f "$REPO/pyproject.toml" ]; then
    git clone "$AECP_REPO_URL" "$REPO"
  fi
fi
ARCH="$(uname -m)"
case "$ARCH" in
  aarch64) JAVA_HOME="${AECP_JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-arm64}" ;;
  x86_64)  JAVA_HOME="${AECP_JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}" ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac
export AECP_JAVA_HOME="$JAVA_HOME" AECP_APPS="$APPS" AECP_DATA="$DATA_ROOT" \
       AECP_VENV="$VENV" AECP_REPO="$REPO"

source "$REPO_ROOT/deploy/versions.env" 2>/dev/null \
  || source "$SCRIPT_DIR/../versions.env"

ARCHIVE="$APACHE_ARCHIVE"
GUAC_BASE="https://downloads.apache.org/guacamole/$GUACAMOLE_VERSION"
MAVEN="$MAVEN_BASE"
REQUIRED_PORTS="6650 8091 3181 2181 8082 6122 6123 8983 9876 9877 9860 9861 9863 9862 9865 9872 9878 9888 9891 9864 9856 9857 9859 9882 8083 8087 8090 4822 8847 8815"

# ------------------------------------------------------------------ helpers
log() { echo "[aecp $(date -u +%H:%M:%S)] $*"; }
die() { echo "[aecp FATAL] $*" >&2; exit 1; }

fetch() {  # fetch <url> <dest>
  local url="$1" dest="$2"
  if [ -s "$dest" ]; then log "have $(basename "$dest")"; return 0; fi
  mkdir -p "$(dirname "$dest")"
  log "downloading $(basename "$url")"
  curl -fSL --retry 5 --retry-delay 5 --connect-timeout 30 \
       -o "$dest.part" "$url" || die "download failed: $url"
  mv "$dest.part" "$dest"
}

fetch_soft() {  # fetch_soft <url> <dest>  (non-fatal; for optional checksum sidecars)
  local url="$1" dest="$2"
  if [ -s "$dest" ]; then return 0; fi
  mkdir -p "$(dirname "$dest")"
  if ! curl -fSL --retry 3 --retry-delay 5 --connect-timeout 30 \
       -o "$dest.part" "$url" 2>/dev/null; then
    rm -f "$dest.part"
    log "WARN: optional download unavailable: $url"
    return 1
  fi
  mv "$dest.part" "$dest"
}

sha_ok() {  # sha_ok <file> <sha512-file>
  local f="$1" sums="$2" hash
  [ -s "$sums" ] || { log "WARN: no sha512 for $(basename "$f") (skipping verify)"; return 0; }
  hash="$(sha512sum "$f" | awk '{print $1}')"
  grep -qi "$hash" "$sums" || die "sha512 mismatch: $(basename "$f")"
  log "sha512 OK: $(basename "$f")"
}

extract_tgz() {  # extract_tgz <tgz> <name>
  local tgz="$1" name="$2"
  if [ -d "$APPS/$name" ] && [ -f "$APPS/$name/.aecp-installed" ]; then
    log "extracted: $name"; return 0
  fi
  mkdir -p "$APPS/$name"
  tar -xzf "$tgz" -C "$APPS/$name" --strip-components=1
  touch "$APPS/$name/.aecp-installed"
  chown -R "$AECP_USER:$AECP_USER" "$APPS/$name"
}

dl_dist() {  # dl_dist <url-without-filename> <filename> <name>
  local base="$1" file="$2" name="$3"
  if [ -d "$APPS/$name" ] && [ -f "$APPS/$name/.aecp-installed" ]; then
    log "extracted: $name"; return 0
  fi
  fetch "$base/$file" "$DL/$file"
  if fetch_soft "$base/$file.sha512" "$DL/$file.sha512"; then
    sha_ok "$DL/$file" "$DL/$file.sha512"
  fi
  extract_tgz "$DL/$file" "$name"
}

# ------------------------------------------------------------------ preflight
[ "$(id -u)" -eq 0 ] || die "run as root (sudo)"
[ -e /etc/debian_version ] || die "requires Debian/Ubuntu"
command -v ss >/dev/null 2>&1 || apt-get update -qq
for p in $REQUIRED_PORTS; do
  if ss -tln | awk '{print $4}' | grep -qE ":$p\$"; then
    die "port $p already in use on this host - refusing to install"
  fi
done
FREE_GB="$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"
[ "$FREE_GB" -ge 12 ] || die "need >=12GB disk free, found ${FREE_GB}GB"
MEM_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
MEM_MB=$((MEM_KB / 1024))
[ "$MEM_MB" -ge 8000 ] || die "need >=8GB RAM, found ${MEM_MB}MB"

# ------------------------------------------------------------------ apt deps
if [ "${AECP_SKIP_APT:-0}" != "1" ]; then
  log "apt: installing base packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq \
    "$JDK_PACKAGE" git curl ca-certificates build-essential libtool-bin \
    python3 python3-venv python3-dev \
    libcairo2-dev libjpeg-dev libpng-dev uuid-dev libssl-dev \
    libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev \
    libpango1.0-dev >/dev/null
fi

# ------------------------------------------------------------------ dirs+user
mkdir -p "$APPS" "$DATA_ROOT" "$BIN"
id -u "$AECP_USER" >/dev/null 2>&1 || useradd --create-home \
  --home-dir "/home/$AECP_USER" --shell /bin/bash "$AECP_USER"

# ------------------------------------------------------------------ downloads
log "fetching Apache distributions (sha512-verified)"
dl_dist "$ARCHIVE/pulsar/pulsar-$PULSAR_VERSION" "apache-pulsar-$PULSAR_VERSION-bin.tar.gz" "pulsar"
dl_dist "$ARCHIVE/flink/flink-$FLINK_VERSION" "flink-$FLINK_VERSION-bin-scala_2.12.tgz" "flink"
dl_dist "$ARCHIVE/solr/solr/$SOLR_VERSION" "solr-$SOLR_VERSION.tgz" "solr"
dl_dist "$ARCHIVE/ozone/$OZONE_VERSION" "ozone-$OZONE_VERSION.tar.gz" "ozone"
dl_dist "$ARCHIVE/zeppelin/zeppelin-$ZEPPELIN_VERSION" "zeppelin-$ZEPPELIN_VERSION-bin-all.tgz" "zeppelin"
dl_dist "$ARCHIVE/tomcat/tomcat-10/v$TOMCAT_VERSION/bin" "apache-tomcat-$TOMCAT_VERSION.tar.gz" "tomcat"

# guacamole-server from source (no apt package exists)
if [ ! -x "$BIN/guacd" ]; then
  log "building guacamole-server $GUACAMOLE_VERSION"
  fetch "$GUAC_BASE/source/guacamole-server-$GUACAMOLE_VERSION.tar.gz" \
        "$DL/guacamole-server-$GUACAMOLE_VERSION.tar.gz"
  if fetch_soft "$GUAC_BASE/source/guacamole-server-$GUACAMOLE_VERSION.tar.gz.sha512" \
        "$DL/guacamole-server-$GUACAMOLE_VERSION.tar.gz.sha512"; then
    sha_ok "$DL/guacamole-server-$GUACAMOLE_VERSION.tar.gz" \
           "$DL/guacamole-server-$GUACAMOLE_VERSION.tar.gz.sha512"
  fi
  mkdir -p "$APPS/guac-build"
  tar -xzf "$DL/guacamole-server-$GUACAMOLE_VERSION.tar.gz" -C "$APPS/guac-build" \
      --strip-components=1
  ( cd "$APPS/guac-build" && ./configure >/dev/null && make -j"$(nproc)" >/dev/null \
      && make install >/dev/null && ldconfig )
  ln -sf /usr/local/sbin/guacd "$BIN/guacd"
fi

# Flink <-> Pulsar bridge jars
fetch "$MAVEN/org/apache/flink/flink-connector-pulsar/$FLINK_PULSAR_CONNECTOR_VERSION/flink-connector-pulsar-$FLINK_PULSAR_CONNECTOR_VERSION.jar" \
      "$APPS/flink/lib/flink-connector-pulsar.jar"
fetch "$MAVEN/org/apache/pulsar/pulsar-client-all/$PULSAR_VERSION/pulsar-client-all-$PULSAR_VERSION.jar" \
      "$APPS/flink/lib/pulsar-client-all.jar"

# Guacamole client WAR
fetch "$GUAC_BASE/binary/guacamole-$GUACAMOLE_VERSION.war" "$DL/guacamole.war"

# reclaim disk: verified tarballs are extracted
rm -f "$DL"/apache-pulsar-*.tar.gz* "$DL"/flink-*.tgz* "$DL"/solr-*.tgz* \
      "$DL"/ozone-*.tar.gz* "$DL"/zeppelin-*.tgz* "$DL"/apache-tomcat-*.tar.gz* \
      "$DL"/guacamole-server-*.tar.gz* 2>/dev/null || true

# ------------------------------------------------------------------ configure
log "configuring components"

# Pulsar: web UI off reserved 8080 -> 8091
sed -i 's/^webServicePort=8080/webServicePort=8091/' "$APPS/pulsar/conf/standalone.conf" || true
grep -q '^webServicePort=8091' "$APPS/pulsar/conf/standalone.conf" || \
  echo 'webServicePort=8091' >> "$APPS/pulsar/conf/standalone.conf"
sed -i 's/^webSocketServiceEnabled=true/webSocketServiceEnabled=false/' \
  "$APPS/pulsar/conf/standalone.conf" || true

# Flink (1.20 flink-conf.yaml)
cat > "$APPS/flink/conf/flink-conf.yaml" <<EOF
jobmanager.rpc.address: 127.0.0.1
rest.bind-address: 0.0.0.0
rest.bind-port: 8082
rest.port: 8082
jobmanager.memory.process.size: 640m
taskmanager.memory.process.size: 1240m
taskmanager.numberOfTaskSlots: 2
EOF

# Solr home under data
mkdir -p "$DATA_ROOT/solr/server" "$DATA_ROOT/solr/log"
cp -r "$APPS/solr/server/solr/." "$DATA_ROOT/solr/server/"

# Ozone (2.2 port layout: SCM client RPC 9860, datanode RPC 9861, block RPC
# 9863, SCM web UI 9877, OM RPC 9862, OM web UI 9865, S3G 9878, Recon 9888/9891)
mkdir -p "$DATA_ROOT/ozone/log" "$DATA_ROOT/ozone/meta" "$DATA_ROOT/ozone/dn-data"
cat > "$APPS/ozone/etc/hadoop/ozone-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>ozone.scm.names</name><value>127.0.0.1</value></property>
  <property><name>ozone.scm.address</name><value>127.0.0.1:9860</value></property>
  <property><name>ozone.scm.client.address</name><value>127.0.0.1:9860</value></property>
  <property><name>ozone.scm.datanode.address</name><value>127.0.0.1:9861</value></property>
  <property><name>ozone.scm.block.client.address</name><value>127.0.0.1:9863</value></property>
  <property><name>ozone.scm.http-address</name><value>0.0.0.0:9877</value></property>
  <property><name>ozone.om.address</name><value>127.0.0.1:9862</value></property>
  <property><name>ozone.om.http-address</name><value>127.0.0.1:9865</value></property>
  <property><name>ozone.recon.address</name><value>127.0.0.1:9888</value></property>
  <property><name>ozone.recon.http-address</name><value>0.0.0.0:9891</value></property>
  <property><name>ozone.metadata.dirs</name><value>$DATA_ROOT/ozone/meta</value></property>
  <property><name>ozone.scm.datanode.id.dir</name><value>$DATA_ROOT/ozone/meta</value></property>
  <property><name>ozone.datanode.data.dirs</name><value>$DATA_ROOT/ozone/dn-data</value></property>
  <property><name>ozone.replication</name><value>ONE</value></property>
  <property><name>ozone.server.default.replication</name><value>1</value></property>
  <property><name>ozone.server.default.replication.type</name><value>STANDALONE</value></property>
  <property><name>hdds.scm.safemode.min.datanode</name><value>1</value></property>
  <property><name>ozone.scm.pipeline.limit</name><value>1</value></property>
</configuration>
EOF

# Superset
mkdir -p "$DATA_ROOT/superset"
if [ ! -f "$DATA_ROOT/superset/superset_config.py" ]; then
  SS_KEY="$(openssl rand -hex 32)"
  cat > "$DATA_ROOT/superset/superset_config.py" <<EOF
SECRET_KEY = "$SS_KEY"
SQLALCHEMY_DATABASE_URI = "sqlite:///$DATA_ROOT/superset/superset.db"
FEATURE_FLAGS = {"ALERT_REPORTS": False}
SUPERSET_WEBSERVER_TIMEOUT = 120
EOF
fi
# apache-superset 6.x: default state caches route through SupersetMetastoreCache,
# which crashes on create_app (internal kwarg skew). NullCache overrides keep
# create_app healthy on the reference model (state lives in the metadata DB).
grep -q EXPLORE_FORM_DATA_CACHE_CONFIG "$DATA_ROOT/superset/superset_config.py" || \
cat >> "$DATA_ROOT/superset/superset_config.py" <<'EOF'
CACHE_CONFIG = {"CACHE_TYPE": "NullCache"}
DATA_CACHE_CONFIG = {"CACHE_TYPE": "NullCache"}
THUMBNAIL_CACHE_CONFIG = {"CACHE_TYPE": "NullCache"}
FILTER_STATE_CACHE_CONFIG = {"CACHE_TYPE": "NullCache"}
EXPLORE_FORM_DATA_CACHE_CONFIG = {"CACHE_TYPE": "NullCache"}
EOF

# Tomcat base for Guacamole on 8090
TB="$APPS/tomcat-base"
mkdir -p "$TB/conf" "$TB/logs" "$TB/temp" "$TB/webapps" "$TB/work" \
         "$DATA_ROOT/guacamole/.guacamole" "$DATA_ROOT/guacd"
if [ ! -f "$TB/conf/server.xml" ]; then
  cp "$APPS/tomcat/conf/server.xml" "$TB/conf/server.xml"
  sed -i 's/port="8080"/port="8090"/' "$TB/conf/server.xml"
  sed -i '/8005/d' "$TB/conf/server.xml"
fi
cp "$DL/guacamole.war" "$TB/webapps/guacamole.war"
cat > "$DATA_ROOT/guacamole/.guacamole/guacamole.properties" <<EOF
guacd-hostname: 127.0.0.1
guacd-port: 4822
EOF
GUAC_PW="$(openssl rand -hex 12)"
SSHPW="$(openssl rand -hex 16)"
HASH="$(printf '%s' "$GUAC_PW" | sha256sum | awk '{print $1}')"
cat > "$DATA_ROOT/guacamole/.guacamole/user-mapping.xml" <<EOF
<user-mapping>
  <authorize username="aecpadmin" password="$HASH" encoding="sha256">
    <connection name="AECP Terminal">
      <protocol>ssh</protocol>
      <param name="hostname">127.0.0.1</param>
      <param name="port">22</param>
      <param name="username">$AECP_USER</param>
      <param name="password">$SSHPW</param>
    </connection>
  </authorize>
</user-mapping>
EOF
printf 'guacamole web: aecpadmin / %s\nssh account: %s / %s\n' "$GUAC_PW" "$AECP_USER" "$SSHPW" \
  > "$DATA_ROOT/guacamole/credentials.txt"
chmod 600 "$DATA_ROOT/guacamole/credentials.txt"
echo "$AECP_USER:$SSHPW" | chpasswd

# ------------------------------------------------------------------ python venv
if [ ! -x "$VENV/bin/python" ]; then python3 -m venv "$VENV"; fi
log "installing python packages (aecp)"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -e "$REPO_ROOT[streaming,storage]"
# Superset 6.x is internally broken on py3.12 (sqlalchemy<2 pins resolve to
# 2.x; pandas<2.1 has no py3.12 wheels for 5.x). Dedicated venv on 3.11 (uv)
# with the mature apache-superset 5.0.0.
SVENV="${AECP_SUPERSET_VENV:-$AECP_ROOT/venv-superset}"
# uv is installed via pip into the main venv (absolute path, no PATH fragility)
if [ ! -x "$VENV/bin/uv" ]; then
  "$VENV/bin/pip" install --quiet uv || die "uv install failed"
fi
UV="$VENV/bin/uv"
if [ ! -x "$SVENV/bin/python" ]; then
  "$VENV/bin/uv" venv --python 3.11 --clear "$SVENV" || die "uv venv (py3.11) for superset failed"
fi
# python-geohash (superset dep) has no aarch64 wheels and needs a modern
# Rust toolchain (system cargo is too old for its Cargo.lock).
if ! "$HOME/.cargo/bin/rustc" --version >/dev/null 2>&1; then
  curl -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable \
    --profile minimal >/dev/null 2>&1 || log "WARN: rustup unavailable"
fi
export PATH="$HOME/.cargo/bin:$PATH"
log "installing apache-superset==5.0.0 into dedicated venv (py3.11)"
"$VENV/bin/uv" pip install --python "$SVENV/bin/python" "apache-superset==5.0.0" \
  "marshmallow<4" "marshmallow-sqlalchemy<1.0" || die "apache-superset install failed"
"$VENV/bin/uv" pip install --python "$SVENV/bin/python" "gunicorn" || die "gunicorn install failed"
# keep the main venv clean of the broken 6.x attempt
/opt/aecp/venv/bin/pip uninstall -y apache-superset >/dev/null 2>&1 || true
export AECP_SUPERSET_VENV="$SVENV"

export SUPERSET_CONFIG_PATH="$DATA_ROOT/superset/superset_config.py"
export FLASK_APP="superset.app:create_app()"
if [ ! -f "$DATA_ROOT/superset/.initialized" ]; then
  "$SVENV/bin/superset" db upgrade
  "$SVENV/bin/superset" init
  SUP_PW="$(openssl rand -hex 12)"
  "$SVENV/bin/superset" fab create-admin --username admin --password "$SUP_PW" \
    --firstname A --lastname E --email admin@aecp.local \
    >/dev/null 2>&1 || log "superset admin already exists"
  printf 'superset admin: admin / %s\n' "$SUP_PW" > "$DATA_ROOT/superset/admin.txt"
  chmod 600 "$DATA_ROOT/superset/admin.txt"
  touch "$DATA_ROOT/superset/.initialized"
fi

# ------------------------------------------------------------------ ownership+profile
chown -R "$AECP_USER:$AECP_USER" "$AECP_ROOT" "$DATA_ROOT"
cat > /etc/profile.d/aecp.sh <<EOF
export PATH="$VENV/bin:\$PATH"
export AECP_HOME="$AECP_ROOT"
export AECP_JAVA_HOME="$JAVA_HOME"
export AECP_APPS="$APPS" AECP_DATA="$DATA_ROOT" AECP_VENV="$VENV" AECP_REPO="$REPO_ROOT"
export AECP_SUPERSET_VENV="$SVENV"
EOF
export AECP_SUPERSET_VENV="${SVENV}"

# ------------------------------------------------------------------ units
log "applying systemd units (daemonless cgroup slice)"
"$VENV/bin/aecpctl" apply

# ------------------------------------------------------------------ ozone init
OZ="$APPS/ozone/bin/ozone"
if [ ! -f "$DATA_ROOT/ozone/.scm-initialized" ]; then
  log "initializing Ozone SCM"
  sudo -u "$AECP_USER" env OZONE_HOME="$APPS/ozone" JAVA_HOME="$JAVA_HOME" \
    "$OZ" scm --init || die "ozone scm --init failed (see above)"
  touch "$DATA_ROOT/ozone/.scm-initialized"
  chown "$AECP_USER" "$DATA_ROOT/ozone/.scm-initialized"
fi
log "starting Ozone SCM (OM init requires a running SCM)"
systemctl enable aecp-ozone-scm.service >/dev/null 2>&1 || true
systemctl restart aecp-ozone-scm.service
for i in $(seq 1 30); do
  ss -tln | grep -qE ':9860 ' && break
  sleep 2
done
ss -tln | grep -qE ':9860 ' || die "SCM client RPC port 9860 never came up"
if [ ! -f "$DATA_ROOT/ozone/.om-initialized" ]; then
  rm -rf "$DATA_ROOT/ozone/meta/om" 2>/dev/null || true
  log "initializing Ozone OM"
  sudo -u "$AECP_USER" env OZONE_HOME="$APPS/ozone" JAVA_HOME="$JAVA_HOME" \
    "$OZ" om --init || die "ozone om --init failed (see above)"
  touch "$DATA_ROOT/ozone/.om-initialized"
  chown "$AECP_USER" "$DATA_ROOT/ozone/.om-initialized"
fi

# ------------------------------------------------------------------ start
if [ "${AECP_SKIP_START:-0}" = "1" ] || [ "${1:-}" = "--skip-start" ]; then
  log "start skipped (AECP_SKIP_START/--skip-start)"
  exit 0
fi

log "starting AECP target"
systemctl enable --now aecp.target
log "waiting for services (up to 6 min)"
ok=0
for i in $(seq 1 36); do
  n_active="$("$VENV/bin/python" -c "
from aecp.launcher.aecpd import status
s = status()
print(sum(1 for v in s.values() if v == 'active'))
" 2>/dev/null || echo 0)"
  log "active aecp units: $n_active/14"
  if [ "$n_active" -ge 13 ]; then ok=1; break; fi
  sleep 10
done
if [ "$ok" != "1" ]; then
  die "AECP services not healthy; inspect: systemctl status 'aecp-*' + journalctl -u aecp-pulsar"
fi

log "creating Solr collection aecp_docs (idempotent)"
sudo -u "$AECP_USER" env AECP_SOLR_URL=http://127.0.0.1:8983 \
  "$VENV/bin/python" -c "
from aecp.aimesh.solr_io import create_collection, ping
try:
    print(create_collection('http://127.0.0.1:8983'))
except Exception as e:
    print('create_collection:', e)
print('solr ping:', ping('http://127.0.0.1:8983'))
" || true

"$VENV/bin/aecpctl" health --timeout 10 || die "health check failed post-install"
log "PROVISION COMPLETE - next: scripts/e2e/run_all.sh"