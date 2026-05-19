#!/bin/bash

# This script is called from within the 'openwrt' directory during the build process.
# It applies custom sources provided via GitHub Action inputs.

MODE="$1" # "feeds", "keys", or "configs"

# Function to check if a variable has meaningful content (not just quotes or whitespace)
is_valid() {
    local val="$1"
    # Remove literal single/double quotes and whitespace
    val=$(echo "$val" | sed "s/['\"]//g" | xargs)
    [ -n "$val" ]
}

case "$MODE" in
    "feeds")
        if is_valid "${USER_EXTRA_FEEDS:-}"; then
            echo "Applying extra feeds..."
            # Ensure file ends with a newline before appending
            [ -f feeds.conf.default ] && sed -i '$a\' feeds.conf.default

            while IFS= read -r line; do
                # Only append lines that look like a feed source
                if echo "$line" | grep -qE "^src-"; then
                    echo "$line" >> feeds.conf.default
                fi
            done <<< "$USER_EXTRA_FEEDS"
        fi
        ;;

    "keys")
        # Handle extra APK keys
        if is_valid "${USER_EXTRA_APK_KEYS:-}"; then
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
                # Fallback: if no multi-key format detected, save everything as extra.pub
                echo "$USER_EXTRA_APK_KEYS" > files/etc/apk/keys/extra.pub
            fi
        fi

        # Handle extra APK repositories
        if is_valid "${USER_EXTRA_APK_REPOSITORIES:-}"; then
            echo "Applying extra APK repositories..."
            mkdir -p files/etc/uci-defaults
            echo "$USER_EXTRA_APK_REPOSITORIES" > files/etc/apk/repositories.extra
            cat > files/etc/uci-defaults/99-extra-apk-repositories << 'EOF'
#!/bin/sh
if [ -f /etc/apk/repositories.extra ]; then
    # Ensure file ends with a newline before appending
    sed -i '$a\' /etc/apk/repositories
    cat /etc/apk/repositories.extra >> /etc/apk/repositories
    rm /etc/apk/repositories.extra
fi
EOF
            chmod +x files/etc/uci-defaults/99-extra-apk-repositories
        fi
        ;;

    "configs")
        if is_valid "${USER_EXTRA_CONFIGS:-}"; then
            echo "Applying extra configs..."
            # Ensure file ends with a newline before appending
            [ -f .config ] && sed -i '$a\' .config

            while IFS= read -r line; do
                # Only append lines that look like a config entry
                if echo "$line" | grep -qE "^CONFIG_|^# CONFIG_"; then
                    echo "$line" >> .config
                fi
            done <<< "$USER_EXTRA_CONFIGS"
        fi
        ;;
esac
