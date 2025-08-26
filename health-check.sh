#!/bin/bash

# Ro-dou Health Check Script
# This script provides comprehensive health checks for all Ro-dou services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AIRFLOW_HOST="${AIRFLOW_HOST:-localhost}"
AIRFLOW_PORT="${AIRFLOW_PORT:-8080}"
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-airflow}"
SMTP_HOST="${SMTP_HOST:-localhost}"
SMTP_PORT="${SMTP_PORT:-25}"

# Health check functions
check_airflow_webserver() {
    echo -e "${BLUE}Checking Airflow Webserver...${NC}"
    
    if curl -f -s -o /dev/null "http://${AIRFLOW_HOST}:${AIRFLOW_PORT}/health"; then
        echo -e "${GREEN}✓ Airflow Webserver is healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ Airflow Webserver is not responding${NC}"
        return 1
    fi
}

check_airflow_scheduler() {
    echo -e "${BLUE}Checking Airflow Scheduler...${NC}"
    
    # Check if scheduler process is running
    if pgrep -f "airflow scheduler" > /dev/null; then
        echo -e "${GREEN}✓ Airflow Scheduler is running${NC}"
        return 0
    else
        echo -e "${RED}✗ Airflow Scheduler is not running${NC}"
        return 1
    fi
}

check_postgresql() {
    echo -e "${BLUE}Checking PostgreSQL...${NC}"
    
    if pg_isready -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
        return 0
    else
        echo -e "${RED}✗ PostgreSQL is not ready${NC}"
        return 1
    fi
}

check_smtp_service() {
    echo -e "${BLUE}Checking SMTP Service...${NC}"
    
    if nc -z "${SMTP_HOST}" "${SMTP_PORT}" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ SMTP Service is available${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ SMTP Service is not available (this may be expected)${NC}"
        return 0  # Don't fail overall health check for SMTP
    fi
}

check_airflow_connections() {
    echo -e "${BLUE}Checking Airflow Connections...${NC}"
    
    # Check if we can access the connections API
    if curl -f -s -u "airflow:airflow" "http://${AIRFLOW_HOST}:${AIRFLOW_PORT}/api/v1/connections" > /dev/null; then
        echo -e "${GREEN}✓ Airflow API is accessible${NC}"
        return 0
    else
        echo -e "${RED}✗ Airflow API is not accessible${NC}"
        return 1
    fi
}

check_disk_space() {
    echo -e "${BLUE}Checking Disk Space...${NC}"
    
    # Check if disk usage is below 90%
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -lt 90 ]; then
        echo -e "${GREEN}✓ Disk usage is ${disk_usage}% (healthy)${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Disk usage is ${disk_usage}% (warning)${NC}"
        return 0  # Don't fail for high disk usage, just warn
    fi
}

check_memory_usage() {
    echo -e "${BLUE}Checking Memory Usage...${NC}"
    
    # Check memory usage
    if command -v free > /dev/null; then
        mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
        
        if [ "$mem_usage" -lt 90 ]; then
            echo -e "${GREEN}✓ Memory usage is ${mem_usage}% (healthy)${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Memory usage is ${mem_usage}% (warning)${NC}"
            return 0  # Don't fail for high memory usage, just warn
        fi
    else
        echo -e "${BLUE}ℹ Memory check not available${NC}"
        return 0
    fi
}

check_dags_status() {
    echo -e "${BLUE}Checking DAGs Status...${NC}"
    
    # Try to get DAG list from Airflow API
    if dag_count=$(curl -f -s -u "airflow:airflow" "http://${AIRFLOW_HOST}:${AIRFLOW_PORT}/api/v1/dags" | grep -o '"dag_id"' | wc -l); then
        if [ "$dag_count" -gt 0 ]; then
            echo -e "${GREEN}✓ Found ${dag_count} DAGs loaded${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ No DAGs found${NC}"
            return 0
        fi
    else
        echo -e "${RED}✗ Could not retrieve DAGs list${NC}"
        return 1
    fi
}

# Main health check function
main_health_check() {
    echo -e "${BLUE}🏥 Starting Ro-dou Health Check...${NC}"
    echo ""
    
    local overall_status=0
    
    # Run all health checks
    check_postgresql || overall_status=1
    check_airflow_webserver || overall_status=1
    check_airflow_scheduler || overall_status=1
    check_airflow_connections || overall_status=1
    check_dags_status || overall_status=1
    check_smtp_service  # Don't affect overall status
    check_disk_space    # Don't affect overall status
    check_memory_usage  # Don't affect overall status
    
    echo ""
    
    if [ $overall_status -eq 0 ]; then
        echo -e "${GREEN}🎉 Overall Health Check: PASSED${NC}"
        echo -e "${GREEN}All critical services are healthy${NC}"
    else
        echo -e "${RED}❌ Overall Health Check: FAILED${NC}"
        echo -e "${RED}One or more critical services are unhealthy${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Health check completed at $(date)${NC}"
    
    return $overall_status
}

# Function to run quick health check (for Docker healthcheck)
quick_health_check() {
    # Quick check for essential services only
    curl -f -s -o /dev/null "http://${AIRFLOW_HOST}:${AIRFLOW_PORT}/health" && \
    pg_isready -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" > /dev/null 2>&1
}

# Parse command line arguments
case "${1:-full}" in
    "quick")
        quick_health_check
        ;;
    "full")
        main_health_check
        ;;
    "webserver")
        check_airflow_webserver
        ;;
    "scheduler")
        check_airflow_scheduler
        ;;
    "postgres")
        check_postgresql
        ;;
    "smtp")
        check_smtp_service
        ;;
    "dags")
        check_dags_status
        ;;
    *)
        echo "Usage: $0 [quick|full|webserver|scheduler|postgres|smtp|dags]"
        echo ""
        echo "  quick      - Quick health check for essential services"
        echo "  full       - Complete health check (default)"
        echo "  webserver  - Check only Airflow webserver"
        echo "  scheduler  - Check only Airflow scheduler"
        echo "  postgres   - Check only PostgreSQL"
        echo "  smtp       - Check only SMTP service"
        echo "  dags       - Check only DAGs status"
        exit 1
        ;;
esac