* bookstore-microservices-domain-account
1. start with mysql
2. add liquibase script
3. make a docker image
4. make helm chart
5. install helm chart and test pod is running with API up and accessible


## 1) Start with mysql
to enter the container:
`docker exec -it mysql  sh`

to login as user root:
`mysql -u root -p`
password is my-secret-pw


to create a database:
`CREATE DATABASE account;`

to create a user:
CREATE USER 'sammy'@'localhost' IDENTIFIED BY 'password';

to grant rights for user sammy:
GRANT CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, SELECT, REFERENCES, RELOAD on *.* TO 'sammy'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;

### configure app to use the db
create file: /src/main/resources/application-mysql.yml
update url, username and password in src/main/resources/application-mysql.yml
url: "jdbc:mysql://localhost:3307/account?useUnicode=true&characterEncoding=utf-8" or url: "jdbc:mysql://127.0.0.1:3307/account?useUnicode=true&characterEncoding=utf-8"
mysql: db container name
localhost(127.0.0.1): ip where db is running
3307: port to access db
bookstore: database name

run app with latest update:
`mvn spring-boot:run -Dspring-boot.run.profiles=mysql`
`make start`

## 2) create liquibase scripts
mkdir /home/youqin/Downloads/CSM_HU/_thesis/projects/bookstore/liquibase-micro-account
cd /home/youqin/Downloads/CSM_HU/_thesis/projects/bookstore/liquibase-micro-account
liquibase init project --format=xml --project-defaults-file=liquibase.properties --username=root --password=my-secret-pw --url="jdbc:mysql://localhost:3307/account?useUnicode=true&characterEncoding=utf-8"
sudo cp /home/youqin/Downloads/mysql-connector-j-8.3.0.jar /usr/bin/lib

need to execute the script
liquibase generate-changelog --changelog-file=changelog.xml
liquibase generate-changelog --changelog-file=changelog-02.xml --diff-types=data

https://docs.liquibase.com/start/tutorials/mysql.html#:~:text=To%20use%20Liquibase%20and%20MySQL,xml%20file.


copy changelog to src/main/resource/db/liquibase and edit application-mysql.yaml to enable liquibase and add dependency to pom

drop database account;

add to pom.xml:
<dependency>
<groupId>org.liquibase</groupId>
<artifactId>liquibase-core</artifactId>
<version>4.2.0</version>
</dependency>


## 3) docker image
make image

docker file starts microservice with default profile, but we need to change it to mysql profile.  PROFILES="mysql

## 4) make helm chart

- create helm chart
  (DO NOT USE _ IN THE NAME BECAUSE IT IS FORBIDDEN, instead use - or .)
  helm create micro-account

- edit values.yaml to add connection and create configmap and jobs to create/delete schema in db
  db:
  url: "jdbc:mysql://my-release-mysql.default.svc.cluster.local:3306/account?useUnicode=true&characterEncoding=utf-8"
  host: "my-release-mysql.default.svc.cluster.local"
  database: bookstore
  username: root
  password: should-be-set
  jobDbCreation:
  image: bitnami/mysql:8.0.36-debian-12-r8
  pullPolicy: IfNotPresent

 
### install helm chart
make install

http://127.0.0.1:8080/


Fix liveness probes using /actuator/health
https://spring.io/blog/2020/03/25/liveness-and-readiness-probes-with-spring-boot
