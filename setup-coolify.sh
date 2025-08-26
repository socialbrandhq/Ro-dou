#!/bin/bash

# Ro-dou Coolify Setup Script
# This script automates the initialization process for Coolify deployment

set -e  # Exit on any error

echo "🚀 Starting Ro-dou Coolify Setup..."

# Configuration
AIRFLOW_WEBSERVER_CONTAINER="ro-dou-airflow-webserver-1"
POSTGRES_CONTAINER="ro-dou-postgres-1"
MAX_RETRIES=60
RETRY_INTERVAL=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to wait for a service to be ready
wait_for_service() {
    local container_name=$1
    local health_check_cmd=$2
    local service_name=$3
    local retries=0

    log_info "Waiting for $service_name to be ready..."
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if docker exec "$container_name" $health_check_cmd > /dev/null 2>&1; then
            log_success "$service_name is ready!"
            return 0
        fi
        
        retries=$((retries + 1))
        log_info "Attempt $retries/$MAX_RETRIES - $service_name not ready yet, waiting ${RETRY_INTERVAL}s..."
        sleep $RETRY_INTERVAL
    done
    
    log_error "$service_name failed to start within $((MAX_RETRIES * RETRY_INTERVAL)) seconds"
    return 1
}

# Function to check if Airflow API is ready
wait_for_airflow_api() {
    log_info "Waiting for Airflow API to be ready..."
    wait_for_service "$AIRFLOW_WEBSERVER_CONTAINER" "curl -f -s -LI 'http://localhost:8080/health'" "Airflow API"
}

# Function to create Airflow variable
create_airflow_variable() {
    local key=$1
    local value=$2
    local description=$3
    
    log_info "Creating Airflow variable: $key"
    
    # Check if variable already exists
    if docker exec "$AIRFLOW_WEBSERVER_CONTAINER" curl -f -s -LI "http://localhost:8080/api/v1/variables/$key" --user "airflow:airflow" > /dev/null 2>&1; then
        log_warning "Variable '$key' already exists, skipping..."
        return 0
    fi
    
    # Create the variable
    if docker exec "$AIRFLOW_WEBSERVER_CONTAINER" curl -s -X 'POST' \
        'http://localhost:8080/api/v1/variables' \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        --user "airflow:airflow" \
        -d "{
            \"key\": \"$key\",
            \"value\": \"$value\",
            \"description\": \"$description\"
        }" > /dev/null; then
        log_success "Variable '$key' created successfully"
    else
        log_error "Failed to create variable '$key'"
        return 1
    fi
}

# Function to create Airflow connection
create_airflow_connection() {
    local connection_id=$1
    local conn_type=$2
    local host=$3
    local login=$4
    local password=$5
    local schema=$6
    local port=$7
    local description=$8
    
    log_info "Creating Airflow connection: $connection_id"
    
    # Check if connection already exists
    if docker exec "$AIRFLOW_WEBSERVER_CONTAINER" curl -f -s -LI "http://localhost:8080/api/v1/connections/$connection_id" --user "airflow:airflow" > /dev/null 2>&1; then
        log_warning "Connection '$connection_id' already exists, skipping..."
        return 0
    fi
    
    # Build connection JSON
    local connection_json="{
        \"connection_id\": \"$connection_id\",
        \"conn_type\": \"$conn_type\",
        \"description\": \"$description\",
        \"host\": \"$host\",
        \"login\": \"$login\",
        \"password\": \"$password\""
    
    if [ -n "$schema" ]; then
        connection_json="$connection_json, \"schema\": \"$schema\""
    fi
    
    if [ -n "$port" ]; then
        connection_json="$connection_json, \"port\": $port"
    fi
    
    connection_json="$connection_json }"
    
    # Create the connection
    if docker exec "$AIRFLOW_WEBSERVER_CONTAINER" curl -s -X 'POST' \
        'http://localhost:8080/api/v1/connections' \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        --user "airflow:airflow" \
        -d "$connection_json" > /dev/null; then
        log_success "Connection '$connection_id' created successfully"
    else
        log_error "Failed to create connection '$connection_id'"
        return 1
    fi
}

# Function to activate DAG
activate_dag() {
    local dag_id=$1
    
    log_info "Activating DAG: $dag_id"
    
    if docker exec "$AIRFLOW_WEBSERVER_CONTAINER" curl -s -X 'PATCH' \
        "http://localhost:8080/api/v1/dags/$dag_id" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        --user "airflow:airflow" \
        -d '{"is_paused": false}' > /dev/null; then
        log_success "DAG '$dag_id' activated successfully"
    else
        log_warning "Failed to activate DAG '$dag_id' (it might not exist yet)"
    fi
}

# Main setup process
main() {
    log_info "Starting Ro-dou initialization process..."
    
    # Wait for Postgres to be ready
    wait_for_service "$POSTGRES_CONTAINER" "pg_isready -U airflow" "PostgreSQL"
    
    # Wait for Airflow API to be ready
    wait_for_airflow_api
    
    # Create example variables
    log_info "Creating Airflow variables..."
    create_airflow_variable "termos_exemplo_variavel" "LGPD\nlei geral de proteção de dados\nacesso à informação" "Example search terms for testing"
    create_airflow_variable "path_tmp" "/tmp" "Temporary file path for processing"
    
    # Initialize INLABS database
    log_info "Initializing INLABS database..."
    if docker exec -e PGPASSWORD=airflow "$POSTGRES_CONTAINER" psql -q -U airflow -f /sql/init-db.sql > /dev/null 2>&1; then
        log_success "INLABS database initialized successfully"
    else
        log_warning "INLABS database initialization failed or already exists"
    fi
    
    # Create database connections
    log_info "Creating database connections..."
    create_airflow_connection "inlabs_db" "postgres" "$POSTGRES_CONTAINER" "airflow" "airflow" "inlabs" "5432" "Connection to INLABS database"
    
    # Create INLABS portal connection (using environment variables if available)
    INLABS_LOGIN="${INLABS_PORTAL_LOGIN:-user@email.com}"
    INLABS_PASSWORD="${INLABS_PORTAL_PASSWORD:-password}"
    create_airflow_connection "inlabs_portal" "http" "https://inlabs.in.gov.br/" "$INLABS_LOGIN" "$INLABS_PASSWORD" "" "" "Credential for accessing INLABS Portal"
    
    # Activate INLABS load DAG
    log_info "Activating DAGs..."
    activate_dag "ro-dou_inlabs_load_pg"
    
    log_success "🎉 Ro-dou setup completed successfully!"
    log_info "You can now access:"
    log_info "  - Airflow UI: http://localhost:8080 (airflow/airflow)"
    log_info "  - SMTP4Dev UI: http://localhost:5001"
    log_info ""
    log_warning "Remember to update INLABS portal credentials in Airflow connections for production use!"
}

# Run main function
main "$@"