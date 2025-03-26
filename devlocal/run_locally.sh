#!/bin/env bash
#
# This script will boot strap a local dev/test environment
# with two Docker containers:
#   1) postgres:15.5
#   2) netllama/gorgias-todo:v1 (flask/python Todo app)
#
# The database will be loaded with the required database schema that
# the app expects.  The app will be preconfigured to connect to the
# database.
# The local URL for the app will be generated and ready for use/testing.
#
# The only pre-requisites: 
#   1) a local working Docker environment (you can run the 'docker'
#       command successfully to pull and run containers).
#   2) You have a local 'git clone' of
#       https://github.com/netllama/gorgias-challenge

PG_CONTAINER_NAME="test-pgsql"
TODO_CONTAINER_NAME="test-todo"

# verify that the repo SQL dump is available
verify_dump () {
    local dbdump="dbdump.sql"
    ls ${dbdump} > /dev/null 2>&1
    if [[ $? -ne 0 ]] ; then
        echo -e "[ERROR]\t${dbdump} not found. Verify that the git repo is fully synced locally."
        exit 1
    fi
}

# pull required images from Docker hub
pull_images () {
    local image_names="postgres:15.5 netllama/gorgias-todo:v1"
    for image in ${image_names}; do
        local msg_str="Pulling docker image ${image}."
        echo -e "${msg_str}  Please wait...\n"
        docker pull ${image}
        if [[ $? -ne 0 ]] ; then
            echo -e "[ERROR]\tFailed ${msg_str}.  Aborting\n"
            exit 1
        fi
    done
}

# start the database container and load it with data
start_setup_db () {
    # accept all connections without authentication,
    # since this is a local dev env
    local msg_str="Starting and setting up the database."
    echo "${msg_str}  Please wait...\n"
    docker run --name ${PG_CONTAINER_NAME} -e POSTGRES_PASSWORD=pgsql -e POSTGRES_HOST_AUTH_METHOD=trust -d postgres:15.5
    if [[ $? -ne 0 ]] ; then
        echo -e "[ERROR] Failed ${msg_str}. Aborting\n"
        exit 1
    fi
    # wait a moment for the database to spin up
    sleep 3
    # load the data into the database
    cat dbdump.sql | docker exec -i ${PG_CONTAINER_NAME} psql -U postgres
    if [[ $? -ne 0 ]] ; then
        echo -e "[ERROR] Failed ${msg_str}. Aborting\n"
        exit 1
    fi
}

# start the Todo app
start_todo () {
    # get the DB container local IP, to connect to
    local msg_str="Starting up the app."
    echo -e "${msg_str}  Please wait...\n"
    local db_host_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${PG_CONTAINER_NAME})
    if [[ $? -ne 0 || -z ${db_host_ip} ]] ; then
        echo -e "[ERROR] Failed to get database container IP address. Aborting.\n"
        exit 1
    fi
    docker run -e DBUSER="todolist" -e DBHOST="${db_host_ip}" --name ${TODO_CONTAINER_NAME} -d "netllama/gorgias-todo:v1"
    if [[ $? -ne 0 ]] ; then
        echo -e "[ERROR] Failed ${msg_str}. Aborting.\n"
        exit 1
    fi
    # wait a moment for the app to come up
    sleep 1
}

# generate Todo app URL
todo_connect () {
    local todo_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${TODO_CONTAINER_NAME})
    if [[ $? -ne 0 || -z ${todo_ip} ]] ; then
        echo -e "[ERROR] Failed to get Todo app container IP address. Aborting.\n"
        exit 1
    fi
    local url="http://${todo_ip}:5000"
    echo -e "\n\n[SUCCESS] The test environment is ready! Point your web browser to ${url} begin using the Todo app.\n"
}


# below here is is where the actual commands are called

# verify that the repo SQL dump is available
verify_dump

# pull required images from Docker hub
pull_images

# start and setup the database
start_setup_db

# start the Todo app
start_todo

# generate Todo app URL
todo_connect

exit 0
