FROM apache/airflow:2.10.0-python3.10

# Set timezone for production
ENV TZ=America/Sao_Paulo

USER root

# Install system dependencies if needed
RUN apt-get update && apt-get install -y \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories with proper permissions
RUN mkdir -p /opt/airflow/dags/ro_dou \
    /opt/airflow/dags/ro_dou_src \
    /opt/airflow/dags/dag_load_inlabs \
    /opt/airflow/tests \
    /opt/airflow/schemas \
    && chown -R airflow:root /opt/airflow

# Copy Ro-dou core files from the host Docker context
COPY --chown=airflow:root src /opt/airflow/dags/ro_dou_src
COPY --chown=airflow:root dag_load_inlabs /opt/airflow/dags/dag_load_inlabs
COPY --chown=airflow:root dag_confs /opt/airflow/dags/ro_dou/dag_confs
COPY --chown=airflow:root tests /opt/airflow/tests

# Switch to airflow user for package installation
USER airflow

# Copy requirements files
COPY requirements-uninstall.txt requirements.txt tests-requirements.txt ./

# Uninstall unnecessary packages first
RUN pip uninstall -y -r requirements-uninstall.txt

# Install additional Airflow dependencies
RUN pip install --no-cache-dir \
    apache-airflow-providers-microsoft-mssql==3.9.0 \
    apache-airflow-providers-common-sql==1.16.0

# Install application requirements
RUN pip install --no-cache-dir -r requirements.txt

# Install test requirements for development/testing
RUN pip install --no-cache-dir -r tests-requirements.txt

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1