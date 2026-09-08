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
BUNDLE_ID="com.example.bdjStudioPro"
SUPPORT="$HOME/Library/Application Support"

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
  "$HOME/Library/Caches/BDJ Studio Sample Pad"
  "$HOME/Library/Caches/$BUNDLE_ID"
)

remove_if_present() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    echo "  -> borrando $1"
    rm -rf "$1"
  fi
}

echo "Desinstalando BDJ Studio Sample Pad..."

if [ "$KEEP_APP" != "--sin-app" ] && [ -d "$APP" ]; then
  echo "  -> borrando $APP"
  rm -rf "$APP"
fi

for dir in "${DATA_DIRS[@]}"; do
  remove_if_present "$dir"
done

remove_if_present "$HOME/Library/Preferences/$BUNDLE_ID.plist"

if [ -d "$SUPPORT/BDJ Studio" ] && [ -z "$(ls -A "$SUPPORT/BDJ Studio")" ]; then
  rmdir "$SUPPORT/BDJ Studio" 2>/dev/null || true
fi

echo "Listo. No queda ningún dato de la aplicación."