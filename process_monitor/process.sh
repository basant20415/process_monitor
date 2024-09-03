#!/usr/bin/bash -i


CONFIG_FILE="./process_monitor.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Configuration file is not found. Use default settings."
    UPDATE_INTERVAL=5
    CPU_ALERT_THRESHOLD=90
    MEMORY_ALERT_THRESHOLD=80
fi

LOG_FILE="./process_monitor.log"
check_resource_pid=""

log_message() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$LOG_FILE"
}


list_processes() {
    echo "Listing all running processes:"
    ps aux --sort=-%mem | awk '{print $2, $1, $3, $4, $11}' | column -t
}

process_informations() {
    local pid="$1"
    if [[ -z "$pid" ]]; then
        echo "provide the PID."
        return
    fi

    if ps -p "$pid" > /dev/null; then
        ps -p "$pid" -o pid,ppid,uid,user,%cpu,%mem,comm
    else
        echo "No process found with this PID $pid."
    fi
}

kill_process() {
    local pid="$1"
    if [[ -z "$pid" ]]; then
        echo "provide the PID."
        return
    fi

    if ps -p "$pid" > /dev/null; then
        kill "$pid" && echo "Process $pid terminated."
        log_message "Terminated process $pid."
    else
        echo "No process found with this PID $pid."
    fi
}

process_statistics() {
    echo "System process statistics:"
    echo "Total processes: $(ps -e | wc -l)"
    echo "Memory usage: $(free -m | awk '/Mem:/ {print $3 " MB / " $2 " MB"}')"
    echo "CPU load: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
}

real_time_monitoring() {
    while true; do
        clear
        list_processes
        sleep "$UPDATE_INTERVAL"
    done
}

search_processes() {
    local search_term="$1"
    if [[ -z "$search_term" ]]; then
        echo "provide the search term."
        return
    fi

    ps aux | grep "$search_term" | grep -v "grep"
}


check_resource_usage() {
    while true; do
        ps aux --sort=-%mem | awk 'NR>1 {print $2, $3, $4}' | while IFS=" " read -r pid cpu mem; do
            cpu=$(awk "BEGIN {print $cpu}")
            mem=$(awk "BEGIN {print $mem}")

            if (( $(echo "$cpu > $CPU_ALERT_THRESHOLD" | bc -l) )); then
                log_message "Alert: Process $pid exceeds CPU usage threshold."
            fi

            if (( $(echo "$mem > $MEMORY_ALERT_THRESHOLD" | bc -l) )); then
                log_message "Alert: Process $pid exceeds memory usage threshold."
            fi
        done

        sleep "$UPDATE_INTERVAL"
    done
}



interactive_mode() {
    while true; do
        echo "Process Monitor Menu:"
        echo "1. List running processes"
        echo "2. Process informations"
        echo "3. Kill a process"
        echo "4. Process statistics"
        echo "5. Real-time monitoring"
        echo "6. Search for a process"
        echo "7. Check resource usage"
        echo "8. Exit"

        read -rp "Choose an option: " option

        case $option in
            1) list_processes ;;
            2) 
                read -rp "Enter PID: " pid
                process_informations  "$pid"
                ;;
            3) 
                read -rp "Enter PID: " pid
                kill_process "$pid"
                ;;
            4) process_statistics ;;
            5) real_time_monitoring ;;
            6) 
                read -rp "Enter the search term: " search_term
                search_processes "$search_term"
                ;;
            7)
             
                if [[ -n "$check_resource_pid" && -d /proc/"$check_resource_pid" ]]; then
                    echo "Resource usage monitoring is already running."
                else
                    check_resource_usage &
                    check_resource_pid=$!
                    echo "Resource usage monitoring started."
                fi
                ;;
            8) 
               
                if [[ -n "$check_resource_pid" && -d /proc/"$check_resource_pid" ]]; then
                    kill "$check_resource_pid"
                    wait "$check_resource_pid" 2>/dev/null
                    echo "Resource usage monitoring stopped."
                fi
                exit ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}
interactive_mode