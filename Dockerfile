# syntax=docker/dockerfile:1

FROM amazoncorretto:8u322-al2 as pip-builder

ARG TARGETARCH

RUN yum -y update \
  && yum -y install python3-devel tar gzip git
WORKDIR /deps

RUN pip3 install setuptools \
 && pip3 install wheel \
 && git clone https://github.com/awslabs/aws-glue-libs.git awsglue

WORKDIR /deps/awsglue
ADD awsglue_setup.py setup.py
RUN python3 setup.py bdist_wheel


FROM maven:3.8.4-amazoncorretto-8 AS builder
WORKDIR /deps
ADD pom.xml .
RUN mvn clean package


FROM amazoncorretto:8u322-al2
ENV LANG=en_US.UTF-8
ENV PYSPARK_PYTHON=python3
ENV SPARK_HOME=/opt/spark
ENV SPARK_CONF_DIR=/opt/spark/conf
ENV PYSPARK_PYTHON_DRIVER=python3
ENV HADOOP_CONF_DIR=/opt/spark/conf

ARG TARGETARCH

RUN yum -y update \
  && yum -y install python3-devel tar gzip gcc mariadb-devel mariadb-libs

RUN curl -o /tmp/spark.tgz -L https://aws-glue-etl-artifacts.s3.amazonaws.com/glue-3.0/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3.tgz \
    && mkdir /opt/spark \
    && tar xf /tmp/spark.tgz --strip-components=1 -C /opt/spark

COPY --from=pip-builder /deps/awsglue/dist/awsglue-3.0-py3-none-any.whl /tmp/

RUN pip3 install pyspark==3.1.1 \
  && pip3 install boto3==1.21.2 \
  && pip3 install botocore==1.24.2 \
  && pip3 install PyMySQL==0.9.3 \
  && pip3 install /tmp/awsglue-3.0-py3-none-any.whl \
  && pip3 install mysqlclient==2.1.0

COPY --from=builder /deps/target/lib/ /opt/spark-libs
COPY spark-defaults.conf /opt/spark/conf/
COPY log4j.properties /opt/spark/conf/
RUN rm -f /opt/spark/jars/*guava* \
  && rm -rf /root/.cache \
  && yum clean all \
  && rm -rf /var/cache/yum \
  && rm -rf /tmp/*

EXPOSE 4040
