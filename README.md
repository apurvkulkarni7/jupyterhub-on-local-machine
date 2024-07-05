# Jupyterhub On Local Machine

## Overview

Welcome to JupyterHub-Docker-Local! This project provides a convenient way to set up and run a JupyterHub instance using Docker containers on your local machine. This setup allows multiple users to access their own Jupyter notebooks and environments, making it ideal for classrooms, collaborative projects, or personal development.

## Prerequisites

Before you begin, ensure you have [Docker]() installed on your system. Please refer [installation guide](https://docs.docker.com/get-docker/) to install docker on your system.


## Getting Started
### Clone the Repository

```bash
git clone https://github.com/apurvkulkarni7/jupyterhub-on-local-machine.git
cd jupyterhub-on-local-machine
```

### Setup

1. Make the [local_jupyterhub.sh](./local_jupyterhub.sh) script executable (if not).

    ```bash
    chmod +x local_jupyterhub.sh
    ```
2. Modify the [requirements.txt](./requirements.txt), as per your needs, to install python packages inside the JupyterHub environment.
3. Setup the docker image. You need to do it only once.
    ```bash
    ./local_jupyterhub.sh setup
    ```

### Starting/Stoping JupyterHub Session

To start the JupyterHub session from the image, run:
```bash
./local_jupyterhub.sh start
```

You can also start the JupyterHub session at desired location, by running:
```bash
./local_jupyterhub.sh start /path/to/your/directory
```

To stop the JupyterHub session, run:
```bash
./local_jupyterhub.sh stop
```

## TODO:
- [ ] Make jupyterhub_config.py available for customization.
- [ ] Launching docker with specified resources (CPU and Memory)

## Contributing

Contributions are welcome! Please fork this repository and submit a pull request for any enhancements or bug fixes.

## License

This project is licensed under GNU GPL V3. See the LICENSE file for more details.