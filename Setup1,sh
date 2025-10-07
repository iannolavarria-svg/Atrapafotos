#!/bin/bash
# create_structure_full.sh
# Crea la estructura del proyecto para StaffPlugin (Maven-ready)

set -e

PROJECT="StaffPlugin"
PKG_DIR="${PROJECT}/src/main/java/com/iann/staff"
RES_DIR="${PROJECT}/src/main/resources"

# remove old
rm -rf "${PROJECT}"

# crear carpetas
mkdir -p "${PKG_DIR}/managers"
mkdir -p "${PKG_DIR}/commands"
mkdir -p "${PKG_DIR}/listeners"
mkdir -p "${PKG_DIR}/menus"
mkdir -p "${RES_DIR}"
mkdir -p "${PROJECT}/.github/workflows"

# README y .gitignore
cat > "${PROJECT}/README.md" <<'EOF'
# StaffPlugin

Plugin PaperMC 1.21.9 para moderación — modo staff, ban hammer, inspect, freeze, noclip, decoy, TP, warn y troll menu.
EOF

cat > "${PROJECT}/.gitignore" <<'EOF'
target/
*.iml
.idea/
.vscode/
EOF

echo "Estructura base creada en ./${PROJECT}"
