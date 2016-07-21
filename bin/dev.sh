#MAINTAINER Kaio Magalhaes, Inc.

####### Project configuration example #######
PROJECT_NAME=rails-5
PROJECT_MAIN_LANGUAGE=ruby
#############################################

UPPERCASE_PROJECT_NAME=$(echo $PROJECT_NAME | tr '[a-z]' '[A-Z]')
ATTACH_ON_CONTAINER=$PROJECT_MAIN_LANGUAGE
DB_CONTAINER_NAME=$PROJECT_NAME-db
PROJECT_CONTAINER_NAME=$PROJECT_NAME-$PROJECT_MAIN_LANGUAGE

find_docker_id() {
  echo $(docker ps -a | grep -m 1 $1 | awk '{ print $1 }')
}

attach_to_project_container(){
  echo 'attaching to project container'
  echo 'make sure config/application.yml and config/database.yml are filled out correctly'
  echo 'start app by running `foreman start -f Procfile.dev`'
  docker attach $(find_docker_id $PROJECT_CONTAINER_NAME)
}

start_container(){
  container_name=$1
  docker_id=$(find_docker_id $container_name)
  for action in "stop" "start"
  do
    docker $action $docker_id
  done
}

run_db_container(){
  docker_id=$(find_docker_id $DB_CONTAINER_NAME)
  if [ $docker_id ] ; then
    echo 'Starting db container on docker'
    start_container $DB_CONTAINER_NAME
  else
    echo 'Creating db container'
    docker run --name $DB_CONTAINER_NAME -e POSTGRES_PASSWORD=postgres -d postgres
  fi
}

run_project_container(){
  docker_id=$(find_docker_id $PROJECT_CONTAINER_NAME)

  if [ $docker_id ] ; then
    echo 'Starting project container on docker'
    start_container $PROJECT_CONTAINER_NAME
    attach_to_project_container
  else
    echo 'Creating project container'

    rm -rf tmp
    rm -f log/development.log
    rm -f log/test.log
    cp Dockerfile.development Dockerfile
    docker build -t codelittinc/$PROJECT_NAME .
    rm Dockerfile
    docker run -d \
      -ti \
      --name $PROJECT_CONTAINER_NAME \
      -v $(pwd):/share \
      -p 3000:3000 \
      -p 4000:4000 \
      --link $DB_CONTAINER_NAME:db codelittinc/$PROJECT_NAME /bin/bash -l

    docker_id=$(find_docker_id $PROJECT_CONTAINER_NAME)
    docker start $docker_id

    docker exec -it $docker_id echo 'Running bundle install'
    docker exec -it $docker_id bundle install
    docker exec -it $docker_id npm install --unsafe-perm
    docker exec -it $docker_id echo 'Setup the database'
    docker exec -it $docker_id rake db:setup
    docker exec -it $docker_id rake db:seed
    attach_to_project_container
  fi
}

init(){
  run_db_container
  run_project_container
}

init
