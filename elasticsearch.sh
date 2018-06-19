#!/usr/bin/env bash

echo "Running elasticsearch.sh"

stackName=$1
license=$2
version=$3
cbpluginversion=$4

echo "Got the parameters:"
echo stackName \'$stackName\'
echo license \'$license\'
echo version \'$version\'

if [[ $license = "NULL" ]]
then
  echo "Installing ElasticSearch..."
  wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${version}.rpm
  rpm --install elasticsearch-${version}.rpm
fi

yum -y update
yum -y install jq

region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
  | jq '.region'  \
  | sed 's/^"\(.*\)"$/\1/' )

instanceID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
  | jq '.instanceId' \
  | sed 's/^"\(.*\)"$/\1/' )

echo "Using the settings:"
echo stackName \'$stackName\'
echo region \'$region\'
echo instanceID \'$instanceID\'

aws ec2 create-tags \
  --region ${region} \
  --resources ${instanceID} \
  --tags Key=Name,Value=${stackName}-ElasticSearch

cd /usr/share/elasticsearch/bin
./elasticsearch-plugin install https://github.com/couchbaselabs/elasticsearch-transport-couchbase/releases/download/${cbpluginversion}-cypress/elasticsearch-transport-couchbase-${cbpluginversion}-cypress-es${version}.zip --batch
./elasticsearch-plugin install discovery-ec2 --batch

curl -LO https://github.com/mobz/elasticsearch-head/archive/master.zip
unzip master.zip
yum install -y gcc-c++ make
yum install -y nodejs
npm install
npm run start & 

./elasticsearch-plugin install discovery-ec2 --batch

file="/etc/elasticsearch/elasticsearch.yml"
echo '
http.publish_host: _ec2:publicDns_
network.publish_host: _ec2:publicDns_
network.bind_host: 0.0.0.0
couchbase.username: Administrator
couchbase.password: password
couchbase.maxConcurrentRequests: 1024
http.cors.enabled: true
http.cors.allow-origin: "*"
' > ${file}

# Need to restart to load the changes
service elasticsearch stop
service elasticsearch start
