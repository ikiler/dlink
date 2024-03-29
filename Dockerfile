FROM flink:1.17.2-scala_2.12-java11 as base

COPY ./coscli /usr/local/bin/coscli
COPY ./.cos.yaml /root/.cos.yaml

ENV TZ=Asia/Shanghai

RUN chmod +x /usr/local/bin/coscli && \
    coscli cp cos://flink-checkpoint-1251517753/data/lib/sources.list /etc/apt/ && \
    coscli cp cos://flink-checkpoint-1251517753/data/lib/goosefs-lite-1.0.4.tar /opt && \
    cd /opt && tar -xf goosefs-lite-1.0.4.tar && \
    apt-get update && \
    apt-get install  -y libfuse-dev sudo && \
    chmod -R 777 /opt && \
    mkdir -m 777 -p /data/goosefs/logs/fuse && \
    chmod -R 777 /data && \
    ln -snf /user/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "flink          ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
#    rm -rf /var/lib/apt/lists && \
#    rm -rf /var/cache


#sudo -E /opt/goosefs-lite-1.0.4/bin/goosefs-lite mount -o"ro,allow_other" /opt/app/ cosn://flink-checkpoint-1251517753/data/app/dev/



FROM  node:18.15.0-alpine3.17 AS ui-build
WORKDIR /user/src/app

ENV NODE_OPTIONS=--openssl-legacy-provider
ENV UMI_ENV=production

# 单独分离 package.json，是为了安装依赖可最大限度利用缓存
ADD dinky-web/package.json /user/src/app/package.json
RUN npm config set registry http://10.2.4.16:8081/repository/group-npm && \
    npm install --legacy-peer-deps
ADD ./dinky-web .
RUN npm run build

FROM maven:3.9.6-amazoncorretto-11 AS build
WORKDIR /user/src/app
ADD pom.xml pom.xml
RUN mvn dependency:go-offline -B --fail-never -Dmaven.test.skip=true -P prod,scala-2.12,flink-single-version,flink-1.17,jdk11,sopei
ADD . .
COPY --from=ui-build /user/src/app/dist/ /user/src/app/dinky-web/dist/
RUN mvn package -Dmaven.test.skip=true -P prod,scala-2.12,flink-single-version,1.17,jdk11,fast,sopei && \
    cd build && \
    tar -xvf dinky-release-1.17-1.0.1.tar.gz && \
    mv dinky-release-1.17-1.0.1 /dinky

FROM base

COPY --from=build /dinky /dinky

RUN set -eux && \
    mkdir ./plugins/s3-fs-hadoop && \
    cp /opt/flink/opt/flink-s3-fs-hadoop-*.jar /opt/flink/plugins/s3-fs-hadoop/ && \
    mkdir ./plugins/s3-fs-presto && \
    cp /opt/flink/opt/flink-s3-fs-presto-*.jar /opt/flink/plugins/s3-fs-presto/ && \
    rm -rf /opt/flink/lib/flink-table-planner-loader* && \
    mv  /opt/flink/opt/flink-table-planner_2.12-*.jar /opt/flink/lib && \
    mv /dinky/jar/dinky-app-*.jar /opt/flink/lib && \
    rm -rf /dinky/lib/log4j* && \
    chmod -R 777 /opt/flink/lib && \
    chmod -R 777 /dinky/ && \
    rm -rf /opt/flink/opt \
    curl -o /opt/flink/lib/mysql.jar "http://10.2.4.16:8081/repository/maven-public/com/mysql/mysql-connector-j/8.0.32/mysql-connector-j-8.0.32.jar"


