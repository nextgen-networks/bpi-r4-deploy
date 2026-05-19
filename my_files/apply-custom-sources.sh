#!/bin/bash

# This script is called from within the 'openwrt' directory during the build process.
# It applies custom sources provided via GitHub Action inputs.

MODE="$1" # "feeds", "keys", or "configs"

case "$MODE" in
    "feeds")
        if [ -n "${USER_EXTRA_FEEDS:-}" ]; then
            echo "Applying extra feeds..."
            echo "" >> feeds.conf.default
            echo "$USER_EXTRA_FEEDS" >> feeds.conf.default
        fi
        ;;

    "keys")
        # Handle extra APK keys
        if [ -n "${USER_EXTRA_APK_KEYS:-}" ]; then
            echo "Applying extra APK keys..."
            mkdir -p files/etc/apk/keys
            if echo "$USER_EXTRA_APK_KEYS" | grep -q ':$'; then
                current_file=""
                while IFS= read -r line; do
                    if echo "$line" | grep -q '^[^ ]*: *$'; then
                        keyname=$(echo "$line" | sed 's/: *$//')
                        current_file="files/etc/apk/keys/$keyname"
                        : > "$current_file"
                    elif [ -n "$current_file" ]; then
                        echo "$line" >> "$current_file"
                    fi
                done <<< "$USER_EXTRA_APK_KEYS"
            else
                echo "$USER_EXTRA_APK_KEYS" > files/etc/apk/keys/extra.pub
            fi
        fi

        # Handle extra APK repositories
        if [ -n "${USER_EXTRA_APK_REPOSITORIES:-}" ]; then
            echo "Applying extra APK repositories..."
            mkdir -p files/etc/uci-defaults
            echo "$USER_EXTRA_APK_REPOSITORIES" > files/etc/apk/repositories.extra
            cat > files/etc/uci-defaults/99-extra-apk-repositories << 'EOF'
#!/bin/sh
if [ -f /etc/apk/repositories.extra ]; then
    cat /etc/apk/repositories.extra >> /etc/apk/repositories
    rm /etc/apk/repositories.extra
fi
EOF
            chmod +x files/etc/uci-defaults/99-extra-apk-repositories
        fi
        ;;

    "configs")
        if [ -n "${USER_EXTRA_CONFIGS:-}" ]; then
            echo "Applying extra configs..."
            echo "" >> .config
            echo "$USER_EXTRA_CONFIGS" >> .config
        fi
        ;;
esac
