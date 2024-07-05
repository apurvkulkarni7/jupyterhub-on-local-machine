#!/bin/bash

###############################################################################
# Help funciton
help () {
  echo "About:"
  echo "This script starts jupyterhub session on local machine using docker."
  echo ""
  echo "Usage:"
  echo "$0 <help|setup|start|stop> [/path/to/directory/on/local_machine]"
  echo ""
  echo -e "  help         : Print this message"
  echo -e "  setup        : Setup docker image"
  echo -e "  start [path] : Start JupyterHub Instance at provided directory."
  echo -e "                 Default is current working directory"
  echo -e "  stop         : Stop JupyterHub Instance"
  echo ""
  exit 0
}
# Stopping and removing running containers based on provided docker image
stop_remove_containers() {
  local DOCKER_IMAGE_NAME=$1
  local RUNNING_CONTAINERS="$(docker ps -a --filter "ancestor=${DOCKER_IMAGE_NAME}" --format "{{.ID}}")"
  for CONTAINER_i in ${RUNNING_CONTAINERS}; do
    docker stop "${CONTAINER_i}" 2>&1 > /dev/null
    docker container remove "${CONTAINER_i}" 2>&1 > /dev/null
  done
}
# Check if docker is installed or not
check_docker_installation(){
  # Check if Docker is already installed
  if ! command -v docker &> /dev/null; then
    logger "error" "Docker is not installed. Please visit following website for more information:"
    logger "error" "https://docs.docker.com/get-docker/"
    logger "error" "Exiting..."
    exit 1
  fi
}
# Creating Dockerfile
create_dockerfile() {
  local DOCKER_USER=$1
  cat << EOF > ./Dockerfile
# Use the official JupyterHub image from Docker Hub
FROM jupyterhub/jupyterhub:latest

# Install system dependencies
USER root
RUN apt-get update && apt-get install -y npm openjdk-11-jdk wget git \
    && rm -rf /var/lib/apt/lists/*

# Install configurable-http-proxy
RUN pip install configurable-http-proxy
#npm cache clean --force && npm install -g configurable-http-proxy

# Install PySpark
ENV SPARK_VERSION=3.5.1
ENV HADOOP_VERSION=3
RUN wget -qO- "https://downloads.apache.org/spark/spark-3.5.1/spark-3.5.1-bin-hadoop3.tgz" | \
    tar xvz -C /opt/ && \
    ln -s "/opt/spark-\${SPARK_VERSION}-bin-hadoop\${HADOOP_VERSION}" /opt/spark

# Set environment variables for Spark
ENV SPARK_HOME=/opt/spark
ENV PATH=\$SPARK_HOME/bin:\$PATH

# Switch back to jovyan user
RUN useradd -ms /bin/bash ${DOCKER_USER}
USER ${DOCKER_USER}

WORKDIR /home/${DOCKER_USER}/

# Install Python packages from requirements.txt
RUN python3 -m pip install --upgrade pip 

# Installing basic libraries
RUN pip install jupyterhub jupyter_server jupyterlab

# Copy the entrypoint script into the container
COPY --chown=${DOCKER_USER}:users requirements.txt ./

# Installing from requirements.txt
RUN pip install -r requirements.txt

# Copy the entrypoint script into the container
COPY --chown=${DOCKER_USER}:users entrypoint.sh /home/${DOCKER_USER}/.entrypoint.sh

RUN chmod +x /home/${DOCKER_USER}/.entrypoint.sh

# Expose the JupyterHub port
EXPOSE 8000

# Set the entrypoint to the script
ENTRYPOINT ["/home/${DOCKER_USER}/.entrypoint.sh"]

EOF
}
# Creating entrypoint script
create_entrypoint_script() {
  local DOCKER_USER=$1
  cat << EOF > ./entrypoint.sh 
#!/bin/bash

echo "c = get_config()" > /srv/jupyterhub/jupyterhub_config.py
echo "c.JupyterHub.bind_url = 'http://0.0.0.0:8000'" >> /srv/jupyterhub/jupyterhub_config.py
echo "c.JupyterHub.base_url = '/'" >> /srv/jupyterhub/jupyterhub_config.py
echo "c.JupyterHub.authenticator_class = 'dummy'" >> /srv/jupyterhub/jupyterhub_config.py
echo "c.DummyAuthenticator.password = ''" >> /srv/jupyterhub/jupyterhub_config.py
echo "c.JupyterHub.allow_named_servers = True" >> /srv/jupyterhub/jupyterhub_config.py
echo "c.Authenticator.allow_all = True" >> /srv/jupyterhub/jupyterhub_config.py
echo "c.Spawner.notebook_dir = '/home/${DOCKER_USER}/notebooks'" >> /srv/jupyterhub/jupyterhub_config.py

# Start JupyterHub
jupyterhub --config=/srv/jupyterhub/jupyterhub_config.py >> /srv/jupyterhub/jupyterhub_config.py

EOF
}
# Setting up docker image
setup_docker_image() {
  local DOCKER_USER=$1
  local DOCKER_IMAGE_NAME=$2
  create_dockerfile "${DOCKER_USER}"
  create_entrypoint_script "${DOCKER_USER}"
  # Building docker image
  docker build -t "${DOCKER_IMAGE_NAME}" .
  rm ./Dockerfile ./entrypoint.sh
}
# Starting docker
start_jupyterhub_docker () {
  local DOCKER_USER=$1
  local DOCKER_CONTAINER_NAME=$2
  local DOCKER_IMAGE_NAME=$3
  local WORKDIR=$4
  stop_remove_containers "$DOCKER_IMAGE_NAME"
  docker run -d \
      -v "${WORKING_DIR}:/home/${DOCKER_USER}/notebooks" \
      -p 8000:8000 \
      --user root \
      --name "${DOCKER_CONTAINER_NAME}" \
      "${DOCKER_IMAGE_NAME}"

  if [[ "$?" == "125" ]]; then
    logger "error" "The docker image (${DOCKER_IMAGE_NAME}) doesn't exist."
    logger "error" "Create a new image using: $0 setup"
    exit 1
  fi
}
# Printing information after starting juppyterhub docker
print_start_info() {
  local DOCKER_USER=$1
  logger "info" "In your browser, go to following web address to start working"
  logger "info" "  http://0.0.0.0:8000"
  logger "info" ""
  logger "info" "Use following information at the login screen:"
  logger "info" "  Username: ${DOCKER_USER}"
  logger "info" "  No password. Keep it blank."
}
# Main function
main () {
  local CMD=$1 # setup, start, stop
  local WORKING_DIR=${2:-"$PWD"} # Working directoryin local machine
  local DOCKER_IMAGE_NAME="local-jupyterhub"
  local DOCKER_CONTAINER_NAME="${DOCKER_IMAGE_NAME}_container"
  local DOCKER_USER="user"
  check_docker_installation
  if [[ "${CMD}" == "setup" ]]; then
    setup_docker_image "${DOCKER_USER}" "${DOCKER_IMAGE_NAME}"
  elif [[ "${CMD}" == "start" ]]; then
    logger "info" "Starting JupyterHub session"
    start_jupyterhub_docker \
      "${DOCKER_USER}" \
      "${DOCKER_CONTAINER_NAME}" \
      "${DOCKER_IMAGE_NAME}" \
      "${WORKDIR}"
    print_start_info "${DOCKER_USER}"
  elif [[ "${CMD}" == "stop" ]]; then
    logger "info" "Stopping JupyterHub session"
    stop_remove_containers "$DOCKER_IMAGE_NAME"
  fi
}
# Logging function
logger() {
  if [[ "$1" == "info" ]]; then
    echo "[INFO ]: $2"
  elif [[ "$1" == "error" ]]; then
    echo "[ERROR]: $2"
  fi
}
###############################################################################

if [[ "$1" == "help" ]] || [[ "$#" < "1" ]]; then
  help
elif ! [[ "$1" =~ ^(help|setup|start|stop)$ ]]; then
  logger "error" "Wrong input ($1). For info, run: \"$0 help\""
  exit 1
else
  main "$1" "$2"
fi 

# End of script