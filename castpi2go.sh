#!/bin/bash

SSH_DIR="$HOME/.ssh"
VARS_FILE="./vars/ssh_config.yaml"
ANSIBLE_CFG="./ansible.cfg"
HOST_VARS_DIR="./host_vars"

update_ssh_config() {
    read -p "Create SSH key(s)? Skip this step if you already have a default SSH key and an ansible specific SSH key. (y/n): " choice
    if [ "$choice" == "y" ]; then
        cd $SSH_DIR
        read -p "Enter a user name and create a default SSH key (or input 's' to skip): " choice
        if [ "$choice" != "s" ]; then
            ssh-keygen -t ed25519 -C "$choice default" -f "$HOME/.ssh/$choice"
            echo "Copy this public ssh key into the SSH field in Raspberry Pi Imager:"
            cat "$HOME/.ssh/$choice.pub"
            sleep 5
        fi
        read -p "Create an SSH key for ansible? (don't use a password) (y/n): " choice
        if [ "$choice" == "y" ]; then
            ssh-keygen -t ed25519 -C "ansible" -f "$HOME/.ssh/ansible"
        fi
    fi
    read -p "Configure the SSH key and user for ansible? (y/n): " choice
    if [ "$choice" == "y" ]; then
        default_user=$(grep '^user_for_ansible:' "$VARS_FILE" | awk '{print $2}')

        echo "Available public SSH keys in $SSH_DIR:"
        mapfile -t keys < <(find "$SSH_DIR" -type f -name "*.pub")

        if [[ ${#keys[@]} -eq 0 ]]; then
            echo "No public SSH keys found in $SSH_DIR."
            return 1
        fi

        select key in "${keys[@]}"; do
            if [[ -n "$key" ]]; then
                ssh_key_content=$(<"$key")
                break
            else
                echo "Invalid selection. Try again."
            fi
        done

        read -rp "Enter username for Ansible (press Enter to keep default: $default_user): " new_user
        [[ -z "$new_user" ]] && new_user="$default_user"

        sed -i \
            -e "s|^user_for_ansible:.*|user_for_ansible: $new_user|" \
            -e "s|^user_for_ansible_ssh_key:.*|user_for_ansible_ssh_key: \"$ssh_key_content\"|" \
            "$VARS_FILE"
        echo "Updated $VARS_FILE"

        if [[ "$new_user" != "$default_user" ]]; then
            sed -i "s/^remote_user *=.*/remote_user = $new_user/" "$ANSIBLE_CFG"
            echo "Updated $ANSIBLE_CFG"
        fi

    fi
}

# Check for a valid IP address
ip_validation() {
    if [[ ! "$1" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
        echo "WARNING: $1 does not appear to be a valid IP."
    fi
}

# Check if an IP exists (commented or not) in a given section
ip_exists_in_section() {
    local ip="$1"
    local section="$2"
    awk -v ip="$ip" -v section="$section" '
        BEGIN { in_section=0 }
        $0 ~ ("^\\[" section "\\]") { in_section=1; next }
        /^\[/ && in_section { in_section=0 }
        in_section && $0 ~ ip { found=1 }
        END { exit !found }
    ' "inventory"
}

# Add or uncomment an IP in the given section of the inventory file
ensure_ip_in_inventory_section() {
    local ip="$1"
    local section="$2"

    # Check if IP exists (commented or not)
    local match_line
    match_line=$(awk -v ip="$ip" -v section="$section" '
        BEGIN { in_section=0 }
        $0 ~ ("^\\[" section "\\]") { in_section=1; next }
        /^\[/ && in_section { in_section=0 }
        in_section && $0 ~ ip { print $0; exit }
    ' "inventory")

    if [[ -n "$match_line" ]]; then
        if [[ "$match_line" =~ ^[[:space:]]*# ]]; then
            # It's commented → uncomment
            awk -v ip="$ip" -v section="$section" '
                BEGIN { in_section=0 }
                $0 ~ ("^\\[" section "\\]") { in_section=1; print; next }
                /^\[/ && in_section { in_section=0; print; next }
                in_section && $0 ~ ip {
                    sub(/^#/, "")
                    gsub(/^[ \t]+/, "")
                }
                { print }
            ' "inventory" > "inventory.tmp" && mv "inventory.tmp" "inventory"
            echo "IP $ip was commented out — now uncommented in [$section] of inventory."
        else
            echo "IP $ip already present and active in [$section] of inventory, nothing to do."
        fi
    else
        # Not found → append
        awk -v ip="$ip" -v section="$section" '
            BEGIN { in_section=0 }
            $0 ~ ("^\\[" section "\\]") { in_section=1; print; next }
            /^\[/ && in_section {
                in_section=0
                print ip
            }
            { print }
            END {
                if (in_section) {
                    print ip
                }
            }
        ' "inventory" > "inventory.tmp" && mv "inventory.tmp" "inventory"
        echo "IP $ip added to [$section] section of inventory."
    fi
}

add_to_inventory() {
    local finished=0

    while [ $finished -ne 1 ]; do
        read -p "IP of the pi (required): " pi_ip
        read -p "Friendly name of the pi (required): " pi_name
        read -p "Hifiberry device tree, see: https://www.hifiberry.com/docs/software/configuring-linux-3-18-x/ (press Enter if no DAC is used): " pi_dtoverlay
        read -p "Snapcast server IP (press Enter if snapcast is not used): " pi_snapserver_ip

        echo "IP: $pi_ip" && ip_validation "$pi_ip"
        echo "Friendly name: $pi_name"
        [[ -n $pi_dtoverlay ]] && echo "Hifiberry device tree: $pi_dtoverlay"
        [[ -n $pi_snapserver_ip ]] && echo "Snapcast server IP: $pi_snapserver_ip" && ip_validation "$pi_snapserver_ip"

        read -p "Does this look correct? (y/n/q): " choice
        case $choice in
            y)
                if [ "$pi_ip" != "$pi_snapserver_ip" ]; then
                    ensure_ip_in_inventory_section "$pi_ip" "snapclients"
                fi
                read -p "Add snapserver IP: $pi_snapserver_ip to inventory? Info: Don't add it if the snapserver is not managed by castpi2go. (y/n): " choice
                    if [ "$choice" == "y" ]; then
                        [[ -n "$pi_snapserver_ip" ]] && ensure_ip_in_inventory_section "$pi_snapserver_ip" "snapservers"
                    fi
                output_file="host_vars/$pi_ip.yml"
                echo "friendly_name: $pi_name" > "$output_file"
                [[ -n $pi_dtoverlay ]] && echo "hifiberry_overlay: $pi_dtoverlay" >> "$output_file"
                [[ -n $pi_snapserver_ip ]] && echo "snapcast_server_ip: $pi_snapserver_ip" >> "$output_file"
                echo "Saved pi config to $output_file."
                finished=1
                ;;
            n) echo "Try again.";;
            q) echo "Returning."; finished=1 ;;
            *) echo "You didn't enter a valid choice. Enter q to quit." ;;
        esac
    done
}

run_bootstrap() {
    # Prompt for username
    read -rp "Enter username to run the bootstrap playbook as (the same you used in Raspberry Pi Imager): " ansible_user
    if [[ -z "$ansible_user" ]]; then
        echo "Username cannot be empty."
        return 1
    fi

    # List private keys (exclude .pub files)
    echo "Available private SSH keys in $SSH_DIR:"
    mapfile -t private_keys < <(find "$SSH_DIR" -type f ! -name "*.pub")

    if [[ ${#private_keys[@]} -eq 0 ]]; then
        echo "No private SSH keys found in $SSH_DIR."
        return 1
    fi

    select key in "${private_keys[@]}"; do
        if [[ -n "$key" ]]; then
            echo "Selected key: $key"
            break
        else
            echo "Invalid selection. Try again."
        fi
    done

    # Parse inventory to find non-commented host/group names
    echo "Scanning inventory for available hosts or groups..."
    mapfile -t available_hosts < <(grep -vE '^\s*#|^\s*$|^\[' ./inventory | awk '{print $1}' | sort -u)

    if [[ ${#available_hosts[@]} -eq 0 ]]; then
        echo "No usable hosts found in ./inventory"
        return 1
    fi

    echo "Available hosts/groups in inventory:"
    select chosen_host in "${available_hosts[@]}" "Run on ALL hosts"; do
        if [[ "$REPLY" -gt 0 && "$REPLY" -le "${#available_hosts[@]}" ]]; then
            limit_option="--limit $chosen_host"
            break
        elif [[ "$chosen_host" == "Run on ALL hosts" ]]; then
            limit_option=""
            break
        else
            echo "Invalid selection. Try again."
        fi
    done

    # Run ansible-playbook
    echo "Running Ansible bootstrap playbook..."
    ansible-playbook bootstrap.yml -u "$ansible_user" --key-file "$key" $limit_option
}

run_main() {
    # Parse inventory to find non-commented host/group names
    echo "Scanning inventory for available hosts or groups..."
    mapfile -t available_hosts < <(grep -vE '^\s*#|^\s*$|^\[' ./inventory | awk '{print $1}' | sort -u)

    if [[ ${#available_hosts[@]} -eq 0 ]]; then
        echo "No usable hosts found in ./inventory"
        return 1
    fi

    echo "Available hosts/groups in inventory:"
    select chosen_host in "${available_hosts[@]}" "Run on ALL hosts"; do
        if [[ "$REPLY" -gt 0 && "$REPLY" -le "${#available_hosts[@]}" ]]; then
            limit_option="--limit $chosen_host"
            break
        elif [[ "$chosen_host" == "Run on ALL hosts" ]]; then
            limit_option=""
            break
        else
            echo "Invalid selection. Try again."
        fi
    done

    # Run ansible-playbook
    echo "Running main Ansible playbook..."
    ansible-playbook castpi2go.yml $limit_option
}

list_hosts() {
    if [[ ! -d "$HOST_VARS_DIR" ]]; then
        echo "Directory $HOST_VARS_DIR does not exist."
        return 1
    fi

    shopt -s nullglob  # avoid literal *.yml if no files match
    for file in "$HOST_VARS_DIR"/*.yml; do
        ip=$(basename "$file" .yml)
        echo -e "\nIP: $ip"
        sed -e 's/^friendly_name:/Friendly Name:/I' \
            -e 's/^hifiberry_overlay:/Hifiberry Overlay:/I' \
            -e 's/^snapcast_server_ip:/Snapcast Server IP:/I' "$file"
    done
    shopt -u nullglob
}

finished=0

while [ $finished -ne 1 ]; do
    echo "Castpi2go convenience script"
    
    echo "1 - Configure SSH keys and users"
    echo "2 - Add a pi to the inventory"
    echo "3 - Run ansible bootstrap playbook"
    echo "4 - Run ansible main playbook"
    echo "5 - List all configured hosts"
    echo "6 - Exit script"


    read choice;

    case $choice in
        1) update_ssh_config;;
        2) add_to_inventory;;
        3) run_bootstrap;;
        4) run_main;;
        5) list_hosts;;
        6) finished=1;;
        *) echo "You didn't enter a valid choice."
    esac
done

echo "Have fun with your pis, exiting."