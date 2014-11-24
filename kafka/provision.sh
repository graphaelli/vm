#!/bin/bash -ex

#
# Install [locally hosted] RPMs
#  * http://www.oracle.com/technetwork/java/javase/downloads/index.html
#
rpm -i /tmp/pkg/*rpm

# Use Oracle java (disabled since zk-server rpm hardcodes full path to openjdk apparently)
alternatives --install /usr/bin/java java /usr/java/jdk1.7.0_71/bin/java 1
update-alternatives --set java /usr/java/jdk1.7.0_71/bin/java

#
# User & perms
#
/usr/sbin/useradd --comment "Kafka" --shell /bin/bash -M -r -U -d /var/lib/kafka kafka

#
# Setup kakfa
#
tar -C /usr/local -zxf /tmp/pkg/src/kafka_2.10-0.8.1.1.tgz
ln -sf /usr/local/kafka_2.10-0.8.1.1 /usr/local/kafka
mkdir -p /etc/kafka /var/lib/kafka
mkdir -p /usr/local/kafka/logs  # this is pretty dumb
ln -s /usr/local/kafka/logs /var/log/kafka
chown -R kafka:kafka /var/lib/kafka /usr/local/kafka/logs

#
# Write kafka configs
#
cat > /etc/kafka/server.properties <<EOF
broker.id=$SEQUENCE_ID
port=9092

num.network.threads=2
num.io.threads=8
num.partitions=2

socket.send.buffer.bytes=1048576
socket.receive.buffer.bytes=1048576
socket.request.max.bytes=104857600

log.dirs=/var/lib/kafka
log.retention.hours=168
log.segment.bytes=536870912
log.retention.check.interval.ms=60000
log.cleaner.enable=false

zookeeper.connect=192.168.33.51:2181,192.168.33.52:2181,192.168.33.53:2181
zookeeper.connection.timeout.ms=1000000
EOF

cat > /etc/kafka/log4j.properties <<EOF
kafka.logs.dir=/var/log/kafka

log4j.rootLogger=INFO
log4j.appender.stdout=org.apache.log4j.ConsoleAppender
log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.kafkaAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.kafkaAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.kafkaAppender.File=\${kafka.logs.dir}/server.log
log4j.appender.kafkaAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.kafkaAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.stateChangeAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.stateChangeAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.stateChangeAppender.File=\${kafka.logs.dir}/state-change.log
log4j.appender.stateChangeAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.stateChangeAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.requestAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.requestAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.requestAppender.File=\${kafka.logs.dir}/kafka-request.log
log4j.appender.requestAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.requestAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.cleanerAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.cleanerAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.cleanerAppender.File=log-cleaner.log
log4j.appender.cleanerAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.cleanerAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.controllerAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.controllerAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.controllerAppender.File=\${kafka.logs.dir}/controller.log
log4j.appender.controllerAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.controllerAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

# Turn on all our debugging info
#log4j.logger.kafka.producer.async.DefaultEventHandler=DEBUG, kafkaAppender
#log4j.logger.kafka.client.ClientUtils=DEBUG, kafkaAppender
#log4j.logger.kafka.perf=DEBUG, kafkaAppender
#log4j.logger.kafka.perf.ProducerPerformance\$ProducerThread=DEBUG, kafkaAppender
#log4j.logger.org.I0Itec.zkclient.ZkClient=DEBUG
log4j.logger.kafka=INFO, kafkaAppender

log4j.logger.kafka.network.RequestChannel\$=WARN, requestAppender
log4j.additivity.kafka.network.RequestChannel\$=false

#log4j.logger.kafka.network.Processor=TRACE, requestAppender
#log4j.logger.kafka.server.KafkaApis=TRACE, requestAppender
#log4j.additivity.kafka.server.KafkaApis=false
log4j.logger.kafka.request.logger=WARN, requestAppender
log4j.additivity.kafka.request.logger=false

log4j.logger.kafka.controller=TRACE, controllerAppender
log4j.additivity.kafka.controller=false

log4j.logger.kafka.log.LogCleaner=INFO, cleanerAppender
log4j.additivity.kafka.log.LogCleaner=false

log4j.logger.state.change.logger=TRACE, stateChangeAppender
log4j.additivity.state.change.logger=false
EOF

cat > /etc/sysconfig/kafka <<EOF
KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:///etc/kafka/log4j.properties"
EOF

#
# Start kafka
#
cat > /usr/lib/systemd/system/kafka.service <<EOF
[Unit]
Description=Apache Kafka server (broker)
Documentation=http://kafka.apache.org/documentation.html
Requires=network.target
After=network.target
ConditionPathExists=/etc/kafka/server.properties
ConditionPathExists=/etc/kafka/log4j.properties
ConditionPathExists=/var/lib/kafka
ConditionPathExists=/var/log/kafka

[Service]
Type=forking
User=kafka
Group=kafka
WorkingDirectory=/var/lib/kafka
#Environment="KAFKA_HEAP_OPTS=\"-Xmx1G -Xms1G\" KAFKA_LOG4J_OPTS=\"-Dlog4j.configuration=file:///etc/kafka/log4j.properties\""
#ExecStart=/usr/local/kafka/bin/kafka-run-class.sh -name kafkaServer kafka.Kafka /etc/kafka/server.properties
ExecStart=/usr/local/kafka/bin/kafka-server-start.sh -daemon /etc/kafka/server.properties
ExecStop=/usr/local/kafka/bin/kafka-server-stop.sh
Restart=on-failure
SyslogIdentifier=kafka

[Install]
WantedBy=multi-user.target
EOF

/bin/systemctl enable kafka
/bin/systemctl start kafka.service
