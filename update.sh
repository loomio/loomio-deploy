docker system prune
docker-compose pull
docker-compose down
docker-compose run app rake db:migrate
docker-compose up -d
