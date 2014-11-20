#!/bin/bash -ex

#
# Install [locally hosted] RPMs
#  * yum install yum-plugin-downloadonly && yum install --downloadonly --downloaddir=. zookeeper-server telnet lsof
#  * http://www.oracle.com/technetwork/java/javase/downloads/index.html
#
rpm -i /tmp/pkg/*rpm

# Use Oracle java (disabled since rpm hardcodes full path to openjdk apparently)
#alternatives --install /usr/bin/java java /usr/java/jdk1.7.0_71/bin/java 1
#update-alternatives --set java /usr/java/jdk1.7.0_71/bin/java

#
# Write zookeeper config
#
cat >> /etc/zookeeper/zoo.cfg <<EOF
# The number of milliseconds of each tick (original: 2000)
tickTime=2000

# The number of ticks that the initial synchronization phase can take (original: 10)
initLimit=10

# The number of ticks that can pass between sending a request and getting an acknowledgement (original: 5)
syncLimit=5

# the directory where the snapshot is stored.
dataDir=/var/lib/zookeeper/data
dataLogDir=/var/lib/zookeeper/log

# the port at which the clients will connect
clientPort=2181

# Servers
server.1=192.168.33.51:2182:2183
server.2=192.168.33.52:2182:2183
server.3=192.168.33.53:2182:2183
EOF

cat >> /var/lib/zookeeper/data/myid <<EOF
$SEQUENCE_ID
EOF

#
# Start zookeeper
#
/bin/systemctl start zookeeper.service
