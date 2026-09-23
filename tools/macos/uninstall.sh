#!/bin/bash
# Desinstalación completa de BDJ Studio Sample Pad en macOS.
#
# macOS no tiene un desinstalador: arrastrar la app a la Papelera deja la
# carpeta de datos en ~/Library/Application Support. Este script elimina la
# app y todos los datos que Sample Pad haya creado (base de datos, ajustes,
# almacén cifrado, cachés y preferencias), según la política del producto:
# nada sobrevive a la desinstalación.
#
# Uso:
#     bash tools/macos/uninstall.sh
#     bash tools/macos/uninstall.sh --sin-app   # deja la app; solo borra datos
#
# La app y la carpeta de datos respetan la política en macOS de "arrastrar a la
# Papelera": si el usuario ya la borró antes, el script solo limpia los datos.

set -u

APP="/Applications/BDJ Studio Sample Pad.app"
BUNDLE_ID="com.bdjstudio.samplepadpro"
LEGACY_BUNDLE_ID="com.example.bdjStudioPro"
SUPPORT="$HOME/Library/Application Support"
CACHES="$HOME/Library/Caches"
PREFS="$HOME/Library/Preferences"
SAVED_STATE="$HOME/Library/Saved Application State"

KEEP_APP="${1:-}"

# Carpetas de datos que Sample Pad usa o usó (path_provider resuelve el support
# del usuario con el nombre de la app; versiones antiguas lo dejaban en la
# carpeta de marca, por el paquete o en la raíz). Solo se tocan rutas de la
# propia app; nunca carpetas de otras apps.
DATA_DIRS=(
  "$SUPPORT/BDJ Studio Sample Pad"          # ruta actual
  "$SUPPORT/BDJ Studio/BDJ Studio Sample Pad"
  "$SUPPORT/bdj_studio_sample_pad"
  "$SUPPORT/$BUNDLE_ID"
  "$SUPPORT/$LEGACY_BUNDLE_ID"
  "$CACHES/BDJ Studio Sample Pad"
  "$CACHES/BDJ Studio/BDJ Studio Sample Pad"
  "$CACHES/$BUNDLE_ID"
  "$CACHES/$LEGACY_BUNDLE_ID"
  "$SAVED_STATE/$BUNDLE_ID.savedState"
  "$SAVED_STATE/$LEGACY_BUNDLE_ID.savedState"
)

remove_if_present() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    echo "  -> borrando $1"
    rm -rf "$1"
  fi
}

echo "Desinstalando BDJ Studio Sample Pad en macOS..."

if [ "$KEEP_APP" != "--sin-app" ] && [ -d "$APP" ]; then
  echo "  -> borrando $APP"
  rm -rf "$APP"
fi

for dir in "${DATA_DIRS[@]}"; do
  remove_if_present "$dir"
done

# Preferencias plist
remove_if_present "$PREFS/$BUNDLE_ID.plist"
remove_if_present "$PREFS/$LEGACY_BUNDLE_ID.plist"

# Intentar eliminar entradas del Keychain asociadas a la app
if command -v security &>/dev/null; then
  security delete-generic-password -s "$BUNDLE_ID" 2>/dev/null || true
  security delete-generic-password -s "bdj_sample_pad" 2>/dev/null || true
fi

# Limpieza segura de carpetas padre 'BDJ Studio':
# SOLO se eliminan si están completamente vacías (no hay Search Pro, Wave Video, etc.)
if [ -d "$SUPPORT/BDJ Studio" ] && [ -z "$(ls -A "$SUPPORT/BDJ Studio" 2>/dev/null)" ]; then
  echo "  -> carpeta padre $SUPPORT/BDJ Studio vacía, eliminando"
  rmdir "$SUPPORT/BDJ Studio" 2>/dev/null || true
fi

if [ -d "$CACHES/BDJ Studio" ] && [ -z "$(ls -A "$CACHES/BDJ Studio" 2>/dev/null)" ]; then
  rmdir "$CACHES/BDJ Studio" 2>/dev/null || true
fi

echo "Listo. No queda ningún dato de BDJ Studio Sample Pad."